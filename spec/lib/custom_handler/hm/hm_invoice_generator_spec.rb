describe OpenChain::CustomHandler::Hm::HmInvoiceGenerator do
  let(:hm) { with_customs_management_id(FactoryBot(:company, name: "H&M"), "HENNE") }
  let(:country) { FactoryBot(:country, iso_code: "CA") }
  let(:cdef) { described_class.prep_custom_definitions([:prod_po_numbers])[:prod_po_numbers] }
  let(:prod) do
    p = FactoryBot(:product, importer: hm)
    p.update_custom_value! cdef, "0123456\n 1234567"
    p
  end

  describe "run_schedulable" do
    it "finds the new billable events, new invoiceable events, creates a VFI invoice, bills new entries" do
      billables_to_be_invoiced = double "billables to be invoiced"
      billables_to_be_skipped = double "billables to be skipped"
      detail_tmp = double "detail temp file"
      new_billables = {to_be_invoiced: billables_to_be_invoiced, to_be_skipped: billables_to_be_skipped}
      invoice = FactoryBot(:vfi_invoice, invoice_date: Date.new(2018, 1, 1), invoice_number: "inv num", currency: "USD")
      FactoryBot(:vfi_invoice_line, vfi_invoice: invoice, line_number: 1, charge_description: "descr", charge_amount: 5, charge_code: "code", quantity: 2, unit: "ea", unit_price: 2.50)
      generator = instance_double(described_class)
      report_generator = instance_double(described_class::ReportGenerator)
      cdefs = double("cdefs")

      expect(described_class).to receive(:new).and_return generator
      expect(generator).to receive(:get_new_billables).and_return new_billables
      expect(generator).to receive(:create_invoice).and_return invoice
      expect(generator).to receive(:bill_new_classifications).with(billables_to_be_invoiced, invoice)
      expect(generator).to receive(:cdefs).and_return cdefs
      expect(described_class::ReportGenerator).to receive(:new).with(cdefs).and_return report_generator
      expect(report_generator).to receive(:create_report_for_invoice).with(billables_to_be_invoiced, invoice).and_return detail_tmp
      expect(generator).to receive(:write_non_invoiced_events).with(billables_to_be_skipped)
      expect(generator).to receive(:email_invoice).with(invoice, 'sthubbins@hellhole.co.uk', "HM autobill invoice 12-17", "HM autobill invoice 12-17", detail_tmp)

      Timecop.freeze(DateTime.new(2018, 1, 5)) { described_class.run_schedulable({'email'=>'sthubbins@hellhole.co.uk'}) }
    end
  end

  describe "get_new_billables" do
    it "returns hash separating billables to be invoiced from those to be skipped" do
      cl1 = FactoryBot(:classification, product: prod, country: country)
      prod_2 = FactoryBot(:product, importer: hm)
      prod_2.update_custom_value! cdef, "0123456\n 1234567"
      cl2 = FactoryBot(:classification, product: prod_2, country: country)

      be_invoiced = FactoryBot(:billable_event, billable_eventable: cl1)
      FactoryBot(:invoiced_event, billable_event: be_invoiced, invoice_generator_name: "HmInvoiceGenerator")

      be_non_invoiced = FactoryBot(:billable_event, billable_eventable: cl2)
      FactoryBot(:non_invoiced_event, billable_event: be_non_invoiced, invoice_generator_name: "HmInvoiceGenerator")

      be_new_1 = FactoryBot(:billable_event, billable_eventable: cl1) # skipped because assoc prod already invoiced
      be_new_2 = FactoryBot(:billable_event, billable_eventable: cl2)
      be_new_3 = FactoryBot(:billable_event, billable_eventable: cl2) # skipped because invoices same prod as be_new_2

      r = subject.get_new_billables
      expect(r[:to_be_invoiced]).to eq [be_new_2]
      expect(r[:to_be_skipped]).to contain_exactly(be_new_1, be_new_3)
    end
  end

  describe "all_new_billables" do
    let(:prod) { FactoryBot(:product, importer: hm) }
    let(:classi) { FactoryBot(:classification, product: prod, country: country) }
    let!(:billable) { FactoryBot(:billable_event, billable_eventable: classi, event_type: "classification_new") }

    it "returns expected result" do
      expect(subject.all_new_billables).to eq [billable]
    end

    it "returns no results if classification isn't Canadian" do
      country.iso_code = "US"; country.save!
      expect(subject.all_new_billables).to be_empty
    end

    it "returns no results if event not associated with a classification" do
      billable.update!(billable_eventable: FactoryBot(:entry))
      expect(subject.all_new_billables).to be_empty
    end

    it "returns no results if associated importer isn't H&M" do
      prod.update!(importer: FactoryBot(:company))
      expect(subject.all_new_billables).to be_empty
    end

    it "returns result if billable has an associated invoiced_event from another generator" do
      FactoryBot(:invoiced_event, billable_event: billable, invoice_generator_name: 'foo generator')
      expect(subject.all_new_billables).to eq [billable]
    end

    it "returns no results if billable has an associated invoiced_event from this generator" do
      FactoryBot(:invoiced_event, billable_event: billable, invoice_generator_name: 'HmInvoiceGenerator')
      expect(subject.all_new_billables).to be_empty
    end

    it "returns result if billable has an associated non_invoiced_event from another generator" do
      FactoryBot(:non_invoiced_event, billable_event: billable, invoice_generator_name: 'foo generator')
      expect(subject.all_new_billables).to eq [billable]
    end

    it "returns no results if billable has an associated non_invoiced_event from this generator" do
      FactoryBot(:non_invoiced_event, billable_event: billable, invoice_generator_name: 'HmInvoiceGenerator')
      expect(subject.all_new_billables).to be_empty
    end
  end

  describe "partition_by_order_type" do
    let(:prod2) do
      p = FactoryBot(:product, importer: hm)
      p.update_custom_value! cdef, "0123456\n 2345678"
      p
    end

    it "splits billables according to whether associated product has at least one PO number beginning with 1" do
      cl = FactoryBot(:classification, product: prod)
      cl2 = FactoryBot(:classification, product: prod2)
      billable = FactoryBot(:billable_event, billable_eventable: cl)
      billable2 = FactoryBot(:billable_event, billable_eventable: cl2)
      starts_with_one, doesnt_start_with_one = subject.partition_by_order_type [billable, billable2]
      expect(starts_with_one).to eq [billable]
      expect(doesnt_start_with_one).to eq [billable2]
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
      inv_line = FactoryBot(:vfi_invoice_line)
      be_1 = FactoryBot(:billable_event)
      be_2 = FactoryBot(:billable_event)
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
      be_1 = FactoryBot(:billable_event)
      be_2 = FactoryBot(:billable_event)
      new_billables = [{id: be_1.id},
                       {id: be_2.id}]

      subject.write_non_invoiced_events new_billables

      expect(NonInvoicedEvent.count).to eq 2
      ev = NonInvoicedEvent.all.sort.first
      expect(ev.billable_event).to eq be_1
      expect(ev.invoice_generator_name).to eq "HmInvoiceGenerator"
    end
  end

  describe "partition_with_unique_product" do
    it "takes one event per product, marks the rest 'to be skipped'" do
      p1 = FactoryBot(:product)
      p2 = FactoryBot(:product)
      be1 = FactoryBot(:billable_event, billable_eventable: FactoryBot(:classification, product: p1))
      be2 = FactoryBot(:billable_event, billable_eventable: FactoryBot(:classification, product: p1))
      be3 = FactoryBot(:billable_event, billable_eventable: FactoryBot(:classification, product: p2))

      unique, to_be_skipped = subject.partition_with_unique_product [be1, be2, be3]
      expect(unique).to eq [be1, be3]
      expect(to_be_skipped).to eq [be2]
    end
  end

  describe "partition_with_uninvoiced_product" do
    it "takes events belonging to products that have not been previously invoiced, marks the rest 'to be skipped'" do
      p1 = FactoryBot(:product)
      p2 = FactoryBot(:product)
      be1 = FactoryBot(:billable_event, billable_eventable: FactoryBot(:classification, product: p1))
      be2 = FactoryBot(:billable_event, billable_eventable: FactoryBot(:classification, product: p1))
      FactoryBot(:invoiced_event, billable_event: be2, invoice_generator_name: "HMInvoiceGenerator")
      be3 = FactoryBot(:billable_event, billable_eventable: FactoryBot(:classification, product: p2))

      uninvoiced, to_be_skipped = subject.partition_with_uninvoiced_product [be1, be2, be3]
      expect(uninvoiced).to eq [be3]
      expect(to_be_skipped).to eq [be1, be2]
    end
  end

  describe "ReportGenerator" do
    let(:generator) { described_class::ReportGenerator.new }

    describe "create_report_for_invoice" do
      it "creates and attaches spreadsheet to invoice" do
        stub_paperclip
        inv = FactoryBot(:vfi_invoice, invoice_number: "inv-num")
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

        p1 = FactoryBot(:product)
        p1.update_custom_value! cdef, "23456"
        cl1 = FactoryBot(:classification, product: p1)
        be1 = FactoryBot(:billable_event, billable_eventable: cl1)

        p2 = FactoryBot(:product)
        p2.update_custom_value! cdef, "12345"
        cl2 = FactoryBot(:classification, product: p2)
        be2 = FactoryBot(:billable_event, billable_eventable: cl2)

        p3 = FactoryBot(:product)
        p3.update_custom_value! cdef, "34567"
        cl3 = FactoryBot(:classification, product: p3)
        FactoryBot(:billable_event, billable_eventable: cl3)

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
