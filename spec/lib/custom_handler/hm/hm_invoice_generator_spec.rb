require 'spec_helper'


describe OpenChain::CustomHandler::Hm::HmInvoiceGenerator do
  let(:hm) { Factory(:company, alliance_customer_number: "HENNE", name: "H&M") }
  
  describe "run_schedulable" do
    it "finds the new billable events, new invoiceable events, creates a VFI invoice, bills new entries" do
      billables_to_be_invoiced = double "billables to be invoiced"
      billables_to_be_skipped = double "billables to be skipped"
      new_billables = {to_be_invoiced: billables_to_be_invoiced, to_be_skipped: billables_to_be_skipped}
      invoice = instance_double(VfiInvoice)
      generator = instance_double(described_class)
      report_generator = instance_double(described_class::ReportGenerator)
      cdefs = double("cdefs")
  
      expect(described_class).to receive(:new).and_return generator
      expect(generator).to receive(:get_new_billables).and_return new_billables
      expect(generator).to receive(:create_invoice).and_return invoice
      expect(generator).to receive(:bill_new_classifications).with(billables_to_be_invoiced, invoice)
      expect(generator).to receive(:cdefs).and_return cdefs
      expect(described_class::ReportGenerator).to receive(:new).with(cdefs).and_return report_generator
      expect(report_generator).to receive(:create_report_for_invoice).with(billables_to_be_invoiced, invoice)
      expect(generator).to receive(:write_non_invoiced_events).with(billables_to_be_skipped)

      described_class.run_schedulable
    end
  end

  describe "get_new_billables" do
    let(:country_ca) { Factory(:country, iso_code: "CA", name: "CANADA") }
    let(:country_us) { Factory(:country, iso_code: "US", name: "UNITED STATES") }
    let(:cdef) { described_class.prep_custom_definitions([:prod_po_numbers])[:prod_po_numbers] }
    let(:prod) do 
      p = Factory(:product, importer: hm, unique_identifier: "foo")
      p.update_custom_value! cdef, "0123456\n 1234567"
      p
    end
    
    context "H&M classifications" do

      context "CA classifications that haven't been invoiced" do

        it "returns as 'to_be_invoiced' results for classifications with a product of associated with at least one PO number beginning with 1" do
          cl = Factory(:classification, product: prod, country: country_ca)
          Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
          results = subject.get_new_billables
          expect(results[:to_be_invoiced].count).to eq 1
          expect(results[:to_be_skipped].count).to eq 0
        end

        it "returns as 'to_be_skipped' any results for classifications without a product associated with at least one PO number beginning with 1" do
          prod.update_custom_value! cdef, "0123456\n 2345678"

          cl = Factory(:classification, product: prod, country: country_ca)
          Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
          results = subject.get_new_billables
          expect(results[:to_be_invoiced].count).to eq 0
          expect(results[:to_be_skipped].count).to eq 1
        end

        it "returns no results for CA classifications with a non_invoiced_event" do
          cl = Factory(:classification, product: prod, country: country_ca)
          be = Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
          Factory(:non_invoiced_event, billable_event: be, invoice_generator_name: "HMInvoiceGenerator")
          results = subject.get_new_billables
          expect(results[:to_be_invoiced].count).to eq 0
          expect(results[:to_be_skipped].count).to eq 0
        end
      end

      it "returns no results for CA classifications that are already invoiced" do
        cl = Factory(:classification, product: prod, country: country_ca)
        be = Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        Factory(:invoiced_event, billable_event: be, invoice_generator_name: "HmInvoiceGenerator")
        results = subject.get_new_billables
        expect(results[:to_be_invoiced].count).to eq 0
        expect(results[:to_be_skipped].count).to eq 0
      end

      it "returns no results for non-CA classifications that haven't been invoiced" do
        cl = Factory(:classification, product: prod, country: country_us)
        Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        results = subject.get_new_billables
        expect(results[:to_be_invoiced].count).to eq 0
        expect(results[:to_be_skipped].count).to eq 0
      end
    end

    context "Non-H&M classifications" do
      let(:prod) { Factory(:product, importer: Factory(:company), unique_identifier: "foo") }

      it "returns no results for CA classifications that haven't been invoiced" do
        cl = Factory(:classification, product: prod, country: country_ca)
        Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        results = subject.get_new_billables
        expect(results[:to_be_invoiced].count).to eq 0
        expect(results[:to_be_skipped].count).to eq 0
      end

      it "returns no results for non-CA classifications that haven't been invoiced" do
        cl = Factory(:classification, product: prod, country: country_us)
        Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
        results = subject.get_new_billables
        expect(results[:to_be_invoiced].count).to eq 0
        expect(results[:to_be_skipped].count).to eq 0
      end
    end

    it "returns no results for non-classifications" do
      ent = Factory(:entry, importer: hm)
      Factory(:billable_event, billable_eventable: ent, entity_snapshot: Factory(:entity_snapshot), event_type: "entry_new")
      results = subject.get_new_billables
      expect(results[:to_be_invoiced].count).to eq 0
      expect(results[:to_be_skipped].count).to eq 0
    end

    it "returns as 'to_be_invoiced' results for invoiced CA classifications that have been processed by a different generator" do
      cl = Factory(:classification, product: prod, country: country_ca)
      be = Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
      Factory(:invoiced_event, billable_event: be, invoice_generator_name: "FooGenerator")
      results = subject.get_new_billables
      expect(results[:to_be_invoiced].count).to eq 1
      expect(results[:to_be_skipped].count).to eq 0
    end

    it "returns as 'to_be_invoiced' results that have a non_invoiced_event associated with a different generator" do
      cl = Factory(:classification, product: prod, country: country_ca)
      be = Factory(:billable_event, billable_eventable: cl, entity_snapshot: Factory(:entity_snapshot), event_type: "classification_new")
      Factory(:non_invoiced_event, billable_event: be, invoice_generator_name: "FooGenerator")
      results = subject.get_new_billables
      expect(results[:to_be_invoiced].count).to eq 1
      expect(results[:to_be_skipped].count).to eq 0
    end
  end

  describe "create_invoice" do
    it "creates a new VFI invoice" do
      expected = [hm, Date.today, "VFI-1", "USD"]
      inv = subject.create_invoice
      expect([inv.customer, inv.invoice_date, inv.invoice_number, inv.currency]).to eq expected
    end
  end

  describe "bill_new_classifications" do
    let(:invoice) { double("invoice") }

    it "creates invoiced events for all billables and an invoice line for billables with invoiceable ids" do
      billables = [{id: 1, billable_eventable_id: 2}, {id: 3, billable_eventable_id: 4}, {id: 5, billable_eventable_id: 6}]
      inv_line = double("invoice_line")
      inv_lines_relation = double("inv_lines_relation")
      
      expect(invoice).to receive(:vfi_invoice_lines).and_return inv_lines_relation
      expect(inv_lines_relation).to receive(:create!).with(charge_description: "Canadian classification", quantity: 3, 
                                                       unit: "ea", unit_price: 2.00).and_return inv_line
      expect(subject).to receive(:write_invoiced_events).with(billables, inv_line)

      subject.bill_new_classifications billables, invoice
    end

    it "doesn't create an invoice line if there are no invoiceable events" do
      billables = []
      
      expect(invoice).not_to receive(:vfi_invoice_lines)
      expect(subject).not_to receive(:write_invoiced_events)

      subject.bill_new_classifications billables, @invoice
    end
  end

  describe "write_invoiced_events" do
    it "creates an invoiced event for each new billable" do
      inv_line = Factory(:vfi_invoice_line)
      be_1 = Factory(:billable_event)
      be_2 = Factory(:billable_event)
      new_billables = [{id: be_1.id},            
                       {id: be_2.id}]
      
      subject.write_invoiced_events new_billables, inv_line
      
      expect(InvoicedEvent.count).to eq 2
      ev = InvoicedEvent.all.sort.first
      expected = [be_1, inv_line, "HmInvoiceGenerator", "classification_ca"]
      expect([ev.billable_event, ev.vfi_invoice_line, ev.invoice_generator_name, ev.charge_type]).to eq expected
    end
  end

  describe "write_non_invoiced_events" do
    it "create a non-invoiced event for each new billable" do
      be_1 = Factory(:billable_event)
      be_2 = Factory(:billable_event)
      new_billables = [{id: be_1.id},            
                       {id: be_2.id}]
      
      subject.write_non_invoiced_events new_billables

      expect(NonInvoicedEvent.count).to eq 2
      ev = NonInvoicedEvent.all.sort.first
      expect(ev.billable_event).to eq be_1
      expect(ev.invoice_generator_name).to eq "HmInvoiceGenerator"
    end
  end

  describe "ReportGenerator" do
    let(:generator) { described_class::ReportGenerator.new }

    describe "create_report_for_invoice" do
      it "creates and attaches spreadsheet to invoice" do
        stub_paperclip
        inv = Factory(:vfi_invoice, invoice_number: "inv-num")
        billables = double "billable events"
        workbook_double = XlsMaker.create_workbook 'workbook_double'
        expect(generator).to receive(:create_workbook).with(billables, "inv-num").and_return workbook_double
        generator.create_report_for_invoice(billables, inv)

        expect(inv.attachments.length).to eq 1
        att = inv.attachments.first
        expect(att.attached_file_name).to eq "products_for_inv-num.xls"
        expect(att.attachment_type).to eq "VFI Invoice Support"
      end
    end

    describe "create_workbook" do
      it "returns list of product UIDs corresponding to the specified billable events" do
        generator.cdefs = subject.cdefs
        cdef = subject.cdefs[:prod_part_number]

        p1 = Factory(:product)
        p1.update_custom_value! cdef, "23456"
        cl1 = Factory(:classification, product: p1)
        be1 = Factory(:billable_event, billable_eventable: cl1)
        
        p2 = Factory(:product)
        p2.update_custom_value! cdef, "12345"
        cl2 = Factory(:classification, product: p2)
        be2 = Factory(:billable_event, billable_eventable: cl2)
        
        p3 = Factory(:product)
        p3.update_custom_value! cdef, "34567"
        cl3 = Factory(:classification, product: p3)
        Factory(:billable_event, billable_eventable: cl3)

        wb = generator.create_workbook([be1, be2], "inv num")
        sheet = wb.worksheets[0]
        expect(sheet.name).to eq "inv num"
        expect(sheet.rows.count).to eq 3
        expect(sheet.row(0)[0]).to eq "Part Number"
        expect(sheet.row(1)[0]).to eq "12345"
        expect(sheet.row(2)[0]).to eq "23456"
      end
    end
  end

end