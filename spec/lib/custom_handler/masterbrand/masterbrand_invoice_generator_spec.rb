require 'spec_helper'

describe OpenChain::CustomHandler::Masterbrand::MasterbrandInvoiceGenerator do

  describe "run_schedulable" do
    it "finds the new billable events, creates a VFI invoice, bills new entries and monthly charges" do
      e1 = Factory(:entry)
      e2 = Factory(:entry)
      e3 = Factory(:entry)
      under_limit_billables = [Factory(:billable_event, billable_eventable: e1), Factory(:billable_event, billable_eventable: e2)]
      over_limit_billables = [Factory(:billable_event, billable_eventable: e3)]
      invoice = double "vfi invoice"
      detail_tmp = double "detail tempfile"

      expect(described_class).to receive(:get_new_billables).with(described_class::ENTRY_LIMIT).and_return under_limit_billables
      expect(described_class).to receive(:get_new_billables).and_return over_limit_billables
      expect(described_class).to receive(:create_invoice).and_return invoice
      expect(described_class).to receive(:bill_monthly_charge).with(under_limit_billables, invoice)
      expect(described_class).to receive(:bill_new_entries).with(over_limit_billables, invoice)
      expect_any_instance_of(described_class::ReportGenerator).to receive(:create_report_for_invoice).with([e1.id, e2.id, e3.id], invoice).and_return detail_tmp
      expect(described_class).to receive(:email_invoice).with(invoice, "sthubbins@hellhole.co.uk", "MasterBrand autobill invoice 12-17", "MasterBrand autobill invoice 12-17", detail_tmp)

      Timecop.freeze(DateTime.new(2018,1,5)) { described_class.run_schedulable({'email'=>'sthubbins@hellhole.co.uk'}) }
    end
  end

  describe "get_new_billables" do
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

  describe "create_invoice" do
    it "creates a new VFI invoice" do
      mbci = Factory(:master_company)
      inv = described_class.create_invoice
      expected = [mbci, Date.today, "VFI-1", "USD"]
      expect([inv.customer, inv.invoice_date, inv.invoice_number, inv.currency]).to eq expected
    end
  end

  describe "bill_new_entries" do
    it "writes new billables as invoiced events and creates invoice lines for those of type 'entry_new'" do
      inv = Factory(:vfi_invoice)

      billables = [double('billable')]

      expect(described_class).to receive(:write_invoiced_events).with(billables,instance_of(VfiInvoiceLine))

      expect{described_class.bill_new_entries billables, inv}.to change(inv.vfi_invoice_lines,:count).from(0).to(1)

      line = VfiInvoiceLine.first
      expect(line.quantity).to eq billables.length
      expect(line.unit).to eq 'ea'
      expect(line.unit_price).to eq 2.5
      expect(line.charge_description).to eq 'Unified Entry Audit; Over 250 Entries'
    end
  end

  describe "bill_monthly_charge" do
    it "attaches an invoice line" do
      billables = double('billables')
      expect(described_class).to receive(:write_invoiced_events).with(billables,instance_of(VfiInvoiceLine))
      inv = Factory(:vfi_invoice)
      described_class.bill_monthly_charge billables, inv
      line = VfiInvoice.first.vfi_invoice_lines.first
      expected = [1000, 1, "ea", 1000, "Monthly charge for up to 250 entries"]
      expect([line.charge_amount, line.quantity, line.unit, line.unit_price, line.charge_description]).to eq expected
    end
  end

  describe "write_invoiced_events" do
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

  describe "ReportGenerator" do
    let(:generator) { described_class::ReportGenerator.new }

    describe "create_report_for_invoice" do
      it "creates and attaches spreadsheet to invoice" do
        stub_paperclip
        entry_ids = double "ids"
        inv = Factory(:vfi_invoice, invoice_number: "inv-num")
        workbook_double = XlsMaker.create_workbook 'workbook_double'
        expect(generator).to receive(:create_workbook).with(entry_ids, "inv-num").and_return workbook_double
        generator.create_report_for_invoice(entry_ids, inv)

        expect(inv.attachments.length).to eq 1
        att = inv.attachments.first
        expect(att.attached_file_name).to eq "entries_for_inv-num.xls"
        expect(att.attachment_type).to eq "VFI Invoice Support"
      end
    end

    describe "create_workbook" do
      it "returns list of entry numbers corresponding to the specified billable events" do
        e1 = Factory(:entry, entry_number: "321")
        e2 = Factory(:entry, entry_number: "123")

        wb = generator.create_workbook([e1.id, e2.id], "inv num")
        sheet = wb.worksheets[0]
        expect(sheet.name).to eq "inv num"
        expect(sheet.rows.count).to eq 3
        expect(sheet.row(0)[0]).to eq "Entry Number"
        expect(sheet.row(1)[0]).to eq "123"
        expect(sheet.row(2)[0]).to eq "321"
      end
    end
  end

end
