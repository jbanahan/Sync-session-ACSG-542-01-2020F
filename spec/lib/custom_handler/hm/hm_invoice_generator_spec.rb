require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmInvoiceGenerator do
  
  describe :run_schedulable do
    it "finds the new billable events, new invoiceable events, creates a VFI invoice, bills new entries" do
      new_billables = double("new billables")
      invoice = double("vfi invoice")
  
      expect(described_class).to receive(:get_new_billables).and_return new_billables
      expect(described_class).to receive(:create_invoice).and_return invoice
      expect(described_class).to receive(:bill_new_classifications).with(new_billables, invoice)

      described_class.run_schedulable
    end
  end

  describe :get_new_billables do
    let(:country_ca) { Factory(:country, iso_code: "CA", name: "CANADA") }
    let(:country_us) { Factory(:country, iso_code: "US", name: "UNITED STATES") }
    
    context "H&M classifications" do
      let(:prod) { Factory(:product, importer: Factory(:company, alliance_customer_number: "HENNE", name: "H&M"), unique_identifier: "foo") }

      it "returns no results for CA classifications that are already invoiced" do
        cl = Factory(:classification, product: prod, country: country_ca)
        be = Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        Factory(:invoiced_event, billable_event: be, invoice_generator_name: "HmInvoiceGenerator")
        results = described_class.get_new_billables
        expect(results.count).to eq 0
      end

      it "returns results for CA classifications that haven't been invoiced" do
        cl = Factory(:classification, product: prod, country: country_ca)
        Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        results = described_class.get_new_billables
        expect(results.count).to eq 1
      end

      it "returns no results for non-CA classifications that haven't been invoiced" do
        cl = Factory(:classification, product: prod, country: country_us)
        Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        results = described_class.get_new_billables
        expect(results.count).to eq 0
      end
    end

    context "Non-H&M classifications" do
      let(:prod) { Factory(:product, importer: Factory(:company), unique_identifier: "foo") }

      it "returns no results for CA classifications that haven't been invoiced" do
        cl = Factory(:classification, product: prod, country: country_ca)
        Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        results = described_class.get_new_billables
        expect(results.count).to eq 0
      end

      it "returns no results for non-CA classifications that haven't been invoiced" do
        cl = Factory(:classification, product: prod, country: country_us)
        Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        results = described_class.get_new_billables
        expect(results.count).to eq 0
      end
    end

    it "returns no results for non-classifications" do
      ent = Factory(:entry, importer: Factory(:company, alliance_customer_number: "HENNE", name: "H&M"))
      Factory(:billable_event, billable_eventable: ent, entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      results = described_class.get_new_billables
      expect(results.count).to eq 0
    end

    it "returns results for invoiced CA classifications that have been processed by a different generator" do
      prod = Factory(:product, importer: Factory(:company, alliance_customer_number: "HENNE", name: "H&M"), unique_identifier: "foo")
      cl = Factory(:classification, product: prod, country: country_ca)
      be = Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
      Factory(:invoiced_event, billable_event: be, invoice_generator_name: "FooGenerator")
      results = described_class.get_new_billables
      expect(results.count).to eq 1
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
    let(:invoice) { double("invoice") }

    it "creates invoiced events for all billables and an invoice line for billables with invoiceable ids" do
      billables = [{id: 1, billable_eventable_id: 2}, {id: 3, billable_eventable_id: 4}, {id: 5, billable_eventable_id: 6}]
      inv_line = double("invoice_line")
      inv_lines_relation = double("inv_lines_relation")
      
      expect(invoice).to receive(:vfi_invoice_lines).and_return inv_lines_relation
      expect(inv_lines_relation).to receive(:create!).with(charge_description: "Canadian classification", quantity: 3, 
                                                       unit: "ea", unit_price: 2.00).and_return inv_line
      expect(described_class).to receive(:write_invoiced_events).with(billables, inv_line)

      described_class.bill_new_classifications billables, invoice
    end

    it "doesn't create an invoice line if there are no invoiceable events" do
      billables = []
      
      expect(invoice).not_to receive(:vfi_invoice_lines)
      expect(described_class).not_to receive(:write_invoiced_events)

      described_class.bill_new_classifications billables, @invoice
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