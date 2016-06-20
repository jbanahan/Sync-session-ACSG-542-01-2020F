require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmInvoiceGenerator do
  
  describe :run_schedulable do
    it "finds the new billable events, new invoiceable events, creates a VFI invoice, bills new entries" do
      new_billables = double("new billables")
      new_invoiceable_ids = double("new_invoiceables")
      invoice = double("vfi invoice")
  
      described_class.should_receive(:get_new_billables).and_return new_billables
      described_class.should_receive(:get_new_invoiceable_ids).and_return new_invoiceable_ids
      described_class.should_receive(:create_invoice).and_return invoice
      described_class.should_receive(:bill_new_classifications).with(new_billables, new_invoiceable_ids, invoice)

      described_class.run_schedulable
    end
  end

  describe :get_new_billabes do
    it "gets new billables" do      
      be_1 = Factory(:billable_event, billable_eventable: Factory(:classification), entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
      be_2 = Factory(:billable_event, billable_eventable: Factory(:classification), entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
      be_3 = Factory(:billable_event, billable_eventable: Factory(:classification), entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      Factory(:invoiced_event, billable_event: be_3, invoice_generator_name: "HmInvoiceGenerator")

      filtered_results = [{id: be_1.id, billable_eventable_id: be_1.billable_eventable.id, event_type: "classification_new"},
                          {id: be_2.id, billable_eventable_id: be_2.billable_eventable.id, event_type: "classification_new"}]
      
      new_billables = described_class.get_new_billables.sort_by{ |b| b.id }
      expect(new_billables.map{|b| {id: b.id, billable_eventable_id: b.billable_eventable.id, event_type: b.event_type} })
                          .to eq filtered_results
    end
  end

  describe :get_new_invoiceable_ids do
    context "when retrieving billables that will be invoiced" do
      before :each do
        cou = Factory(:country, iso_code: "CA")
        com = Factory(:company, alliance_customer_number: "HENNE")
        @class_1 = Factory(:classification, product: Factory(:product, importer: com), country: cou)
        @class_2 = Factory(:classification, product: Factory(:product, importer: com), country: cou)
        @be_1 = Factory(:billable_event, billable_eventable: @class_1, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        @be_2 = Factory(:billable_event, billable_eventable: @class_2, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
      end

      it "excludes non-Canadian classification events" do
        @class_2.update_attributes(country: Factory(:country))
        expect(described_class.get_new_invoiceable_ids).to eq [@class_1.id]
      end

      it "excludes classification events not belonging to H&M" do
        p = @class_2.product
        p.update_attributes(importer: Factory(:company))
        expect(described_class.get_new_invoiceable_ids).to eq [@class_1.id]
      end

      it "excludes events with wrong type" do
        @be_2.update_attributes(event_type: "entry_new")
        expect(described_class.get_new_invoiceable_ids).to eq [@class_1.id]
      end

      it "excludes events that aren't new (i.e. a billable with an invoiced event created by this generator)" do
        Factory(:invoiced_event, billable_event: @be_2, invoice_generator_name: "HmInvoiceGenerator")
        expect(described_class.get_new_invoiceable_ids).to eq [@class_1.id]
      end

      it "includes events that have been invoiced by another generator" do
        Factory(:invoiced_event, billable_event: @be_2, invoice_generator_name: "FooGenerator")
        expect(described_class.get_new_invoiceable_ids.sort).to eq [@class_1.id, @class_2.id]
      end
    end
  end  

  describe :create_invoice do
    it "creates a new VFI invoice" do
      hm = Factory(:company, alliance_customer_number: "HENNE")
      inv = described_class.create_invoice
      expected = [hm, Date.today, "VFI-1", "USD"]
      expect([inv.customer, inv.invoice_date, inv.invoice_number, inv.currency]).to eq expected
    end
  end

  describe :bill_new_classifications do
    before :each do
      @billables = [{id: 1, billable_eventable_id: 2}, {id: 3, billable_eventable_id: 4}, {id: 5, billable_eventable_id: 6}]
      @invoiceable_ids = double("int_array")
      @invoice = double("invoice")
    end

    it "creates invoiced events for all billables and an invoice line for billables with invoiceable ids" do
      inv_line = double("invoice_line")
      inv_lines_relation = double("inv_lines_relation")
      split_billables = [[{id: 1, billable_eventable_id: 2}, {id: 3, billable_eventable_id: 4}],
                         [{id: 5, billable_eventable_id: 6}]]
      
      described_class.should_receive(:split_billables).with(@billables, @invoiceable_ids).and_return split_billables
      
      @invoice.should_receive(:vfi_invoice_lines).and_return inv_lines_relation
      inv_lines_relation.should_receive(:create!).with(charge_description: "new Canadian classification", quantity: 2, 
                                                       unit: "ea", unit_price: 2.00).and_return inv_line
      described_class.should_receive(:write_invoiced_events).with(split_billables[0], inv_line)
      described_class.should_receive(:write_invoiced_events).with(split_billables[1])

      described_class.bill_new_classifications @billables, @invoiceable_ids, @invoice
    end

    it "doesn't create an invoice line if there are no invoiceable events" do
      split_billables = [[],
                         [{id: 5, billable_eventable_id: 6}]]
      
      described_class.should_receive(:split_billables).with(@billables, @invoiceable_ids).and_return split_billables
      @invoice.should_not_receive(:vfi_invoice_lines)
      described_class.should_not_receive(:write_invoiced_events).with(split_billables[0])
      described_class.should_receive(:write_invoiced_events).with(split_billables[1])

      described_class.bill_new_classifications @billables, @invoiceable_ids, @invoice
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
      inv_line = Factory(:vfi_invoice_line)
      be_1 = Factory(:billable_event)
      be_2 = Factory(:billable_event)
      new_billables = [{id: be_1.id},            
                       {id: be_2.id}]
      
      described_class.write_invoiced_events new_billables, inv_line
      
      expect(InvoicedEvent.count).to eq 2
      ev = InvoicedEvent.all.sort.first
      expected = [be_1, inv_line, "HmInvoiceGenerator", "classification_ca"]
      expect([ev.billable_event, ev.vfi_invoice_line, ev.invoice_generator_name, ev.charge_type]).to eq expected
    end
  end

end