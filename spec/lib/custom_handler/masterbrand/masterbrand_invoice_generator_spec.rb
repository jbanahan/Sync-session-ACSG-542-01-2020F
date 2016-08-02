require 'spec_helper'

describe OpenChain::CustomHandler::Masterbrand::MasterbrandInvoiceGenerator do

  describe :run_schedulable do
    it "finds the new billable events, creates a VFI invoice, bills new entries and monthly charges" do
      new_billables = double("new billables")
      invoice = double("vfi invoice")

      described_class.should_receive(:get_new_billables).twice.and_return new_billables
      described_class.should_receive(:create_invoice).and_return invoice
      described_class.should_receive(:bill_monthly_charge).with(new_billables, invoice)
      described_class.should_receive(:bill_new_entries).with(new_billables, invoice)

      described_class.run_schedulable
    end
  end

  describe :get_new_billables do
    it "returns no results for entries that have already been invoiced" do
      be = Factory(:billable_event, billable_eventable: Factory(:entry), entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      Factory(:invoiced_event, billable_event: be, invoice_generator_name: "MasterbrandInvoiceGenerator")
      results = described_class.get_new_billables
      expect(results.count).to eq 0
    end

    it "returns no results for billable events with types other than 'entry_new'" do
      Factory(:billable_event, billable_eventable: Factory(:entry), entity_snapshot: Factory(:entity_snapshot), event_type: "entry_foo")
      results = described_class.get_new_billables
      expect(results.count).to eq 0
    end

    it "returns no results for entries with file_logged_date before '2016-05-01'" do
      e = Factory(:entry, file_logged_date: '2016-01-01')
      Factory(:billable_event, billable_eventable: e, entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      results = described_class.get_new_billables
      expect(results.count).to eq 0
    end

    it "returns results for events invoiced with a generator other than MasterbrandInvoiceGenerator" do
      be = Factory(:billable_event, billable_eventable: Factory(:entry), entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      Factory(:invoiced_event, billable_event: be, invoice_generator_name: "FooGenerator")
      results = described_class.get_new_billables
      expect(results.count).to eq 1
    end

    it "returns results for un-invoiced entries with file_logged_date since '2016-05-01' and associated with billable events of type entry_new " do
      e = Factory(:entry, file_logged_date: '2017-01-01')
      Factory(:billable_event, billable_eventable: e, entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      results = described_class.get_new_billables
      expect(results.count).to eq 1
    end

    it "should limit query" do
      results = described_class.get_new_billables 250
      expect(results.to_sql).to match(/LIMIT 250/)
    end
  end

  describe :create_invoice do
    it "creates a new VFI invoice" do
      mbci = Factory(:master_company)
      inv = described_class.create_invoice
      expected = [mbci, Date.today, "VFI-1", "USD"]
      expect([inv.customer, inv.invoice_date, inv.invoice_number, inv.currency]).to eq expected
    end
  end

  describe :bill_new_entries do
    it "writes new billables as invoiced events and creates invoice lines for those of type 'entry_new'" do
      inv = Factory(:vfi_invoice)

      billables = [double('billable')]

      described_class.should_receive(:write_invoiced_events).with(billables,instance_of(VfiInvoiceLine))

      expect{described_class.bill_new_entries billables, inv}.to change(inv.vfi_invoice_lines,:count).from(0).to(1)

      line = VfiInvoiceLine.first
      expect(line.quantity).to eq billables.length
      expect(line.unit).to eq 'ea'
      expect(line.unit_price).to eq 2.5
      expect(line.charge_description).to eq 'Unified Entry Audit; Up To 250 Entries'
    end
  end

  describe :bill_monthly_charge do
    it "attaches an invoice line" do
      billables = double('billables')
      described_class.should_receive(:write_invoiced_events).with(billables,instance_of(VfiInvoiceLine))
      inv = Factory(:vfi_invoice)
      described_class.bill_monthly_charge billables, inv
      line = VfiInvoice.first.vfi_invoice_lines.first
      expected = [1000, 1, "ea", 1000, "Monthly charge for up to 250 entries"]
      expect([line.charge_amount, line.quantity, line.unit, line.unit_price, line.charge_description]).to eq expected
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
