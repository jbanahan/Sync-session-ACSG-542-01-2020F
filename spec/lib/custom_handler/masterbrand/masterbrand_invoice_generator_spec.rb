require 'spec_helper'

describe OpenChain::CustomHandler::Masterbrand::MasterbrandInvoiceGenerator do
  
  describe :run_schedulable do
    it "finds the new billable events, creates a VFI invoice, bills new entries and monthly charges" do
      new_billables = double("new billables")
      invoiceable_ids = double("invoiceable ids")
      invoice = double("vfi invoice")
      company = double("company")
      described_class.should_receive(:get_company).and_return company
      described_class.should_receive(:get_new_billables).and_return new_billables
      described_class.should_receive(:get_new_invoiceable_ids).with(company).and_return invoiceable_ids
      described_class.should_receive(:create_invoice).and_return invoice
      described_class.should_receive(:bill_new_entries).with(new_billables, invoiceable_ids, invoice)
      described_class.should_receive(:bill_monthly_charge).with invoice

      described_class.run_schedulable
    end
  end

  describe :get_company do
    it "retrieves master company" do
      co = Factory(:company)
      expect(described_class.get_company).to be_nil
      co.update_attributes(master: true)
      expect(described_class.get_company).to eq co
    end
  end

  describe :get_new_billables do
    it "gets new billables" do
      be_1 = Factory(:billable_event, billable_eventable: Factory(:entry), entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      be_2 = Factory(:billable_event, billable_eventable: Factory(:entry), entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      be_3 = Factory(:billable_event, billable_eventable: Factory(:entry), entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      Factory(:invoiced_event, billable_event: be_3, invoice_generator_name: "MasterbrandInvoiceGenerator")

      filtered_results = [{id: be_1.id, billable_eventable_id: be_1.billable_eventable.id, event_type: "entry_new"},
                          {id: be_2.id, billable_eventable_id: be_2.billable_eventable.id, event_type: "entry_new"}]
      
      new_billables = described_class.get_new_billables.sort_by{ |b| b.id }
      expect(new_billables.map{|b| {id: b.id, billable_eventable_id: b.billable_eventable.id, event_type: b.event_type} })
                          .to eq filtered_results
    end
  end

  describe :get_new_invoiceable_ids do
    before :each do
      @co = Factory(:company, alliance_customer_number: 'mbci')
      @e_1 = Factory(:entry, importer: @co)
      @e_2 = Factory(:entry, importer: @co)
      @be_1 = Factory(:billable_event, billable_eventable: @e_1, entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      @be_2 = Factory(:billable_event, billable_eventable: @e_2, entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
    end

    it "excludes entry events with a file_logged_date earlier than 5/1/16" do
      @e_2.update_attributes(file_logged_date: "2015/1/1")
      expect(described_class.get_new_invoiceable_ids @co).to eq [@e_1.id]
    end

    it "excludes entry events belonging to any company other than the specified one" do
      @e_2.update_attributes(importer: Factory(:company))
      expect(described_class.get_new_invoiceable_ids @co).to eq [@e_1.id]
    end

    it "excludes events with wrong type" do
      @be_2.update_attributes(event_type: "classification_new")
      expect(described_class.get_new_invoiceable_ids @co).to eq [@e_1.id]
    end

    it "excludes events that aren't new (i.e. a billable with an invoiced event created by this generator)" do
      Factory(:invoiced_event, billable_event: @be_2, invoice_generator_name: "MasterbrandInvoiceGenerator")
      expect(described_class.get_new_invoiceable_ids @co).to eq [@e_1.id]
    end

    it "includes events that have been invoiced by another generator" do
      Factory(:invoiced_event, billable_event: @be_2, invoice_generator_name: "FooGenerator")
      expect(described_class.get_new_invoiceable_ids @co).to eq [@e_1.id, @e_2.id]
    end    
  end

  describe :create_invoice do
    it "creates a new VFI invoice" do
      mbci = Factory(:company)
      inv = described_class.create_invoice mbci
      expected = [mbci, Date.today, "VFI-1", "USD"]
      expect([inv.customer, inv.invoice_date, inv.invoice_number, inv.currency]).to eq expected
    end
  end
  
  describe :bill_new_entries do
    before :each do
      @inv = double("vfi invoice")
      @invoiceable_ids = double("int_array")
      @new_billables = [{billable_event_id: 1, billable_eventable_id: 2, event_type: "entry_new"},
                       {billable_event_id: 5, billable_eventable_id: 6, event_type: "entry_new"},
                       {billable_event_id: 3, billable_eventable_id: 4, event_type: "classification_new"}]
    end

    it "writes new billables as invoiced events and creates invoice lines for those of type 'entry_new'" do
      inv_line = double("vfi invoice line")
      invoice_lines_relation = double("invoice_lines_relation")
      qty_to_be_invoiced = 252
      
      split_billables = [[{billable_event_id: 1, billable_eventable_id: 2, event_type: "entry_new"}, 
                          {billable_event_id: 5, billable_eventable_id: 6, event_type: "entry_new"}],
                         [{billable_event_id: 3, billable_eventable_id: 4, event_type: "classification_new"}]]

      described_class.should_receive(:split_billables).with(@new_billables, @invoiceable_ids).and_return split_billables
      split_billables[0].should_receive(:count).and_return(qty_to_be_invoiced)
      
      @inv.should_receive(:vfi_invoice_lines).and_return invoice_lines_relation
      invoice_lines_relation.should_receive(:create!).with(quantity: 2, unit: "ea", unit_price: 2.50, charge_description: "new entry exceeding 250/mo. limit").and_return inv_line
      described_class.should_receive(:write_invoiced_events).with(split_billables[0], inv_line)
      described_class.should_receive(:write_invoiced_events).with(split_billables[1])

      described_class.bill_new_entries @new_billables, @invoiceable_ids, @inv
    end

    it "doesn't write any invoice lines if there aren't any events of type 'entry_new" do
      split_billables = [[],
                         [{billable_event_id: 5, billable_eventable_id: 6, event_type: "classification_new"}]]

      described_class.should_receive(:split_billables).with(@new_billables, @invoiceable_ids).and_return split_billables
      split_billables[0].should_receive(:count).and_return(0)
      
      described_class.should_receive(:write_invoiced_events).with(split_billables[0])
      described_class.should_receive(:write_invoiced_events).with(split_billables[1])

      described_class.bill_new_entries @new_billables, @invoiceable_ids, @inv
    end
  end

  describe :bill_monthly_charge do
    it "attaches an invoice line" do
      inv = Factory(:vfi_invoice)
      described_class.bill_monthly_charge inv
      line = VfiInvoice.first.vfi_invoice_lines.first
      expected = [1000, 1, "ea", 1000, "monthly charge"]
      expect([line.charge_amount, line.quantity, line.unit, line.unit_price, line.charge_description]).to eq expected
    end
  end

  describe :split_billables do
    it "partitions separates billables that meet invoicing requirements from the rest" do
      billables = [{id: 1, billable_eventable_id: 2}, {id: 3, billable_eventable_id: 4}, {id: 5, billable_eventable_id: 6}]
      invoiceable_ids = [2,4]
      split_billables = [[{id: 1, billable_eventable_id: 2}, {id: 3, billable_eventable_id: 4}],
                         [{id: 5, billable_eventable_id: 6}]]
      
      expect(described_class.split_billables billables, invoiceable_ids).to eq split_billables
    end
  end

  describe :write_invoiced_events do
    it "creates an invoiced event for each new billable" do
      be_1 = Factory(:billable_event)
      be_2 = Factory(:billable_event)
      inv_line = Factory(:vfi_invoice_line)
      new_billables = [{id: be_1.id},            
                       {id: be_2.id}]
      
      described_class.write_invoiced_events new_billables, inv_line
      
      expect(InvoicedEvent.count).to eq 2
      ev = InvoicedEvent.all.sort.first
      expected = [be_1, inv_line, "MasterbrandInvoiceGenerator", "unified_entry_line"]
      expect([ev.billable_event, ev.vfi_invoice_line, ev.invoice_generator_name, ev.charge_type]).to eq expected
    end
  end

end