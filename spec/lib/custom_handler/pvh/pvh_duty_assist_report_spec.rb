require 'open_chain/custom_handler/vfitrack_custom_definition_support'

describe OpenChain::CustomHandler::Pvh::PvhDutyAssistReport do

  let!(:canada) { FactoryBot(:importer, name: 'PVH Canada', system_code: "PVHCANADA") }
  let!(:us) { FactoryBot(:importer, name: 'PVH', system_code: 'PVH') }

  def setup_data(customer_number, company)
    entry1 = FactoryBot(:entry, entry_number: 'entry1', master_bills_of_lading: "1234\n",
                             transport_mode_code: "11", customer_number: customer_number, fiscal_date: Date.new(2020, 2, 10),
                             entry_filed_date: DateTime.parse("02/02/2020 10:45"), release_date: DateTime.parse("02/02/2020 10:45"),
                             import_date: Date.parse("02/02/2020"), arrival_date: Date.parse("02/02/2020"), across_sent_date: Date.parse("04/02/2020"))
    entry2 = FactoryBot(:entry, entry_number: 'entry2', master_bills_of_lading: "2345\n",
                             transport_mode_code: "11", customer_number: customer_number, fiscal_date: Date.new(2020, 2, 11),
                             entry_filed_date: DateTime.parse("02/02/2020 10:45"), release_date: DateTime.parse("02/02/2020 10:45"),
                             import_date: Date.parse("02/02/2020"), arrival_date: Date.parse("02/02/2020"), across_sent_date: Date.parse("03/02/2020"))
    FactoryBot(:broker_invoice, entry: entry1)
    FactoryBot(:broker_invoice, entry: entry2)
    ci1 = FactoryBot(:commercial_invoice, entry: entry1, invoice_number: "invoice1", exchange_rate: "10", currency: "USD")
    ci2 = FactoryBot(:commercial_invoice, entry: entry2, invoice_number: "invoice2", exchange_rate: "10", currency: "CA")
    prod1 = FactoryBot(:product, unique_identifier: "#{customer_number}-abcd")
    prod2 = FactoryBot(:product, unique_identifier: "#{customer_number}-efgh")
    shipment1 = FactoryBot(:shipment, importer: company, master_bill_of_lading: entry1.master_bills_of_lading.gsub(/\n/, ''), mode: "Ocean")
    shipment2 = FactoryBot(:shipment, importer: company, master_bill_of_lading: entry2.master_bills_of_lading.gsub(/\n/, ''), mode: "Ocean")
    sl1 = FactoryBot(:shipment_line, shipment: shipment1, product: prod1)
    sl2 = FactoryBot(:shipment_line, shipment: shipment2, product: prod2)
    container1 = FactoryBot(:container, entry: entry1, shipment_lines: [sl1], container_number: "Container1")
    container2 = FactoryBot(:container, entry: entry2, shipment_lines: [sl2], container_number: "Container2")
    shipment1.containers << container1
    shipment1.save!
    shipment2.containers << container2
    shipment2.save!
    cil1 = FactoryBot(:commercial_invoice_line, commercial_invoice: ci1, part_number: 'abcd', country_origin_code: 'Line1CO',
                                             po_number: "PO1", value_foreign: "1.00", add_to_make_amount: "1.00", contract_amount: "1.00",
                                             unit_price: "100", quantity: 1, value: 3.0, miscellaneous_discount: 100.00, container: container1)
    cil2 = FactoryBot(:commercial_invoice_line, commercial_invoice: ci2, part_number: 'efgh', country_origin_code: 'Line2CO',
                                             po_number: "PO2", value_foreign: "2.00", add_to_make_amount: "2.00", contract_amount: "2.00",
                                             unit_price: 200, quantity: 2, value: 4.0, miscellaneous_discount: 200.00, container: container2)
    FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: cil1, tariff_description: "Tariff One",
                                        entered_value: "1.00", duty_rate: "3", hts_code: "123.12.123")
    FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: cil2, tariff_description: "Tariff Two",
                                        entered_value: "2.00", duty_rate: "4", hts_code: "234.23.234")
    FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: cil1, tariff_description: "Tariff One",
                                        entered_value: "1.00", duty_rate: "3", hts_code: "9903.12.123")
    FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: cil2, tariff_description: "Tariff Two",
                                        entered_value: "2.00", duty_rate: "4", hts_code: "9903.23.234")
    o1 = FactoryBot(:order, importer: company, order_number: "#{customer_number}-PO1")
    o2 = FactoryBot(:order, importer: company, order_number: "#{customer_number}-PO2")
    ol1 = FactoryBot(:order_line, order: o1, product: prod1, line_number: 1, price_per_unit: 100)
    ol2 = FactoryBot(:order_line, order: o2, product: prod2, line_number: 2, price_per_unit: 200)
    PieceSet.create!(order_line: ol1, shipment_line: sl1, quantity: 1)
    PieceSet.create!(order_line: ol2, shipment_line: sl2, quantity: 1)
  end

  describe "permission?" do
    let(:ms) do
      setup = stub_master_setup
      allow(setup).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return true
      setup
    end
    let(:user) do
      u = FactoryBot(:master_user)
      allow(u).to receive(:view_entries?).and_return true
      u
    end

    before { user; ms }

    it "allows www users who can view entries and belong to the master company" do
      expect(described_class.permission?(user)).to eq true
    end

    it "allows www users who can view entries and belong to the pvh_duty_discount_report group" do
      user.company = FactoryBot(:company)
      FactoryBot(:group, system_code: "pvh_duty_discount_report").users << user
      expect(described_class.permission?(user)).to eq true
    end

    it "blocks users on non-www instance" do
      allow(ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return false
      expect(described_class.permission?(user)).to eq false
    end

    it "blocks users without entry-view" do
      allow(user).to receive(:view_entries?).and_return false
      expect(described_class.permission?(user)).to eq false
    end

    it "blocks users who aren't members of the master company or pvh_duty_discount_report group" do
      user.company = FactoryBot(:company)
      expect(described_class.permission?(user)).to eq false
    end
  end

  describe "run_report" do
    let (:u) { FactoryBot(:user) }
    let! (:temp_files) { [] }

    before do
      FactoryBot(:fiscal_month, company: canada, start_date: Date.new(2020, 3, 2), end_date: Date.new(2020, 4, 5), year: 2020, month_number: 2)
      FactoryBot(:fiscal_month, company: canada, start_date: Date.new(2020, 2, 3), end_date: Date.new(2020, 3, 1), year: 2020, month_number: 1)
      FactoryBot(:fiscal_month, company: us, start_date: Date.new(2020, 3, 2), end_date: Date.new(2020, 4, 5), year: 2020, month_number: 2)
      FactoryBot(:fiscal_month, company: us, start_date: Date.new(2020, 2, 3), end_date: Date.new(2020, 3, 1), year: 2020, month_number: 1)
    end

    after do
      temp_files.each(&:close)
    end

    it "raises error when no customer number provided" do
      expect { described_class.run_report(u, {}) }.to raise_error("No customer number provided.")
    end

    context "running report for US" do
      it 'properly handles first sale requirements' do
        setup_data("PVH", us)
        # If first sale, we pull contract amount, otherwise we pull value
        first_sale_true, first_sale_false = CommercialInvoiceLine.all

        first_sale_true.first_sale = true
        first_sale_true.save!
        first_sale_false.first_sale = false
        first_sale_false.value_foreign = 100
        first_sale_false.save!

        Timecop.freeze(DateTime.new(2020, 3, 5, 12, 0)) do
          temp_files << described_class.run_report(u, { 'company' => 'PVH' })
        end
        temp = temp_files.last
        expect(temp.original_filename).to eq "PVH_Data_Dump_Fiscal_2020-01_2020-03-05.xlsx"

        test_reader = XlsxTestReader.new(temp.path).raw_workbook_data
        sheet = test_reader["Results"]
        expect(sheet[1][13]).to eq(0.0)
        expect(sheet[2][13]).to eq(-98.0)
      end

      it "runs report for previous fiscal month for US" do
        setup_data("PVH", us)

        Timecop.freeze(DateTime.new(2020, 3, 5, 12, 0)) do
          temp_files << described_class.run_report(u, { 'company' => 'PVH' })
        end
        temp = temp_files.last
        expect(temp.original_filename).to eq "PVH_Data_Dump_Fiscal_2020-01_2020-03-05.xlsx"

        test_reader = XlsxTestReader.new(temp.path).raw_workbook_data
        sheet = test_reader["Results"]
        expect(sheet[0]).to eq ["Entry Number", "Invoice Number", "Country Of Origin", "PO", "PO Line", "Entry Date",
                                "Import Date", "Product Description/Style Description", "Master Bills", "Arrival Date",
                                "Vendor Invoice Value", "Dutiable Assist", "Dutiable Value", "Duty Adj Amt",
                                "Duty Savings", "Duty Rate", "Price / Unit", "Invoice Quantity", "Exchange Rate",
                                "HTS", "301 HTS", "CN Rate"]
        expect(sheet[1][0]).to eq('entry1')
        expect(sheet[2][0]).to eq('entry2')
        expect(sheet[1][1]).to eq('invoice1')
        expect(sheet[2][1]).to eq('invoice2')
        expect(sheet[1][2]).to eq('Line1CO')
        expect(sheet[2][2]).to eq('Line2CO')
        expect(sheet[1][3]).to eq('PO1')
        expect(sheet[2][3]).to eq('PO2')
        expect(sheet[1][4]).to eq(1)
        expect(sheet[2][4]).to eq(2)
        expect(sheet[1][5]).to eq('02/02/2020')
        expect(sheet[2][5]).to eq('02/02/2020')
        expect(sheet[1][6]).to eq('02/02/2020')
        expect(sheet[2][6]).to eq('02/02/2020')
        expect(sheet[1][7]).to eq("Tariff One")
        expect(sheet[2][7]).to eq("Tariff Two")
        expect(sheet[1][8]).to eq("Container1")
        expect(sheet[2][8]).to eq("Container2")
        expect(sheet[1][9]).to eq("02/01/2020")
        expect(sheet[2][9]).to eq("02/01/2020")
        expect(sheet[1][10]).to eq(3.0)
        expect(sheet[2][10]).to eq(4.0)
        expect(sheet[1][11]).to eq(1.0)
        expect(sheet[2][11]).to eq(2.0)
        expect(sheet[1][12]).to eq(2.0)
        expect(sheet[2][12]).to eq(4.0)
        expect(sheet[1][13]).to eq(0.0)
        expect(sheet[2][13]).to eq(0.0)
        expect(sheet[1][14]).to eq(-0.0)
        expect(sheet[2][14]).to eq(-0.0)
        expect(sheet[1][15]).to eq(300.0)
        expect(sheet[2][15]).to eq(400.0)
        expect(sheet[1][16]).to eq(100.0)
        expect(sheet[2][16]).to eq(200.0)
        expect(sheet[1][17]).to eq(1.0)
        expect(sheet[2][17]).to eq(2.0)
        expect(sheet[1][18]).to eq(10)
        expect(sheet[2][18]).to eq(10)
        expect(sheet[1][19]).to eq("123.12.123")
        expect(sheet[2][19]).to eq("234.23.234")
        expect(sheet[1][20]).to eq("9903.12.123")
        expect(sheet[2][20]).to eq("9903.23.234")
        expect(sheet[1][21]).to eq(300.0)
        expect(sheet[2][21]).to eq(400.0)
      end

      it "sends email if address provided" do
        FiscalMonth.create!(company_id: us.id, year: 2019, month_number: 1, start_date: Date.new(2018, 12, 15), end_date: Date.new(2019, 1, 14))

        Timecop.freeze(Date.new(2019, 9, 30)) do
          described_class.run_report(u, {'fiscal_month' => '2019-01', 'company' => 'PVH', 'email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk']})
        end

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq(['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'])
        expect(mail.subject).to eq("PVH Data Dump")
        expect(mail.body).to include("Attached is the &quot;PVH Data Dump Report, 2019-1&quot; based on ACH Due Date.")
        expect(mail.attachments.count).to eq(1)

        reader = XlsxTestReader.new(StringIO.new(mail.attachments[0].read)).raw_workbook_data
        expect(reader.length).to eq 1
      end

      it "handles quarterly, biannual variations" do
        setup_data("PVH", us)

        settings = {'fiscal_month' => '2019-09', 'company' => 'PVH' }
        scheduling_type = instance_double("scheduling_type")
        expect(described_class).to receive(:scheduling_type).with(settings).and_return(scheduling_type)
        expect_any_instance_of(described_class).to receive(:get_fiscal_period_dates).with('2019-09', nil, scheduling_type, "PVH")
                                                                                    .and_return([DateTime.new(2020, 1, 10), DateTime.new(2020, 2, 10), 1, 2020])
        expect_any_instance_of(described_class).to receive(:filename_fiscal_descriptor).with(2020, 1, scheduling_type).and_return("FISCAL_DESC")

        Timecop.freeze(DateTime.new(2019, 9, 30, 12, 0)) do
          temp_files << described_class.run_report(u, settings)
        end
        temp = temp_files.last

        expect(temp.original_filename).to eq "PVH_Data_Dump_FISCAL_DESC_2019-09-30.xlsx"

        test_reader = XlsxTestReader.new(temp.path).raw_workbook_data
        sheet = test_reader["Results"]
        expect(sheet.length).to eq 2
        expect(sheet[0][0]).to eq('Entry Number')
        expect(sheet[1][0]).to eq('entry1')
      end
    end

    context "running report for Canada" do
      it "runs report for previous fiscal month for Canada" do
        setup_data("PVHCANADA", canada)

        Timecop.freeze(DateTime.new(2020, 3, 5, 12, 0)) do
          temp_files << described_class.run_report(u, { 'company' => 'PVHCANADA' })
        end
        temp = temp_files.last
        expect(temp.original_filename).to eq "PVHCANADA_Data_Dump_Fiscal_2020-01_2020-03-05.xlsx"

        test_reader = XlsxTestReader.new(temp.path).raw_workbook_data
        sheet = test_reader["Results"]
        expect(sheet[0]).to eq ["Entry #", "Invoice #", "PO", "Shipment #", "PO Line", "Release Date", "ETA",
                                "Entry Date", "Import Date", "Style #", "Country of Origin", "Product Description",
                                "HTS #", "Currency Type", "Exchange Rate", "Vendor Invoice Value Calculated (USD)",
                                "Invoice Tariff Entered Value (CAD)", "Duty Assist Amt (USD)", "Duty Deductions (USD)",
                                "Dutiable Value (USD)", "Duty Rate PCT", "Duty Adj Amt (USD)", "Duty Savings (USD)",
                                "First Cost - PO (USD)", "Units Shipped"]
        expect(sheet[1][0]).to eq('entry1')
        expect(sheet[2][0]).to eq('entry2')
        expect(sheet[1][1]).to eq('invoice1')
        expect(sheet[2][1]).to eq('invoice2')
        expect(sheet[1][2]).to eq('PO1')
        expect(sheet[2][2]).to eq('PO2')
        expect(sheet[1][3]).to eq('Container1')
        expect(sheet[2][3]).to eq('Container2')
        expect(sheet[1][4]).to be_nil
        expect(sheet[2][4]).to be_nil
        expect(sheet[1][5]).to eq('02/02/2020')
        expect(sheet[2][5]).to eq('02/02/2020')
        expect(sheet[1][6]).to eq('02/02/2020')
        expect(sheet[2][6]).to eq('02/02/2020')
        expect(sheet[1][7]).to eq("02/03/2020")
        expect(sheet[2][7]).to eq("02/02/2020")
        expect(sheet[1][8]).to eq("02/02/2020")
        expect(sheet[2][8]).to eq("02/02/2020")
        expect(sheet[1][9]).to eq("abcd")
        expect(sheet[2][9]).to eq("efgh")
        expect(sheet[1][10]).to eq("Line1CO")
        expect(sheet[2][10]).to eq("Line2CO")
        expect(sheet[1][11]).to eq("Tariff One")
        expect(sheet[2][11]).to eq("Tariff Two")
        expect(sheet[1][12]).to eq("123.12.123")
        expect(sheet[2][12]).to eq("234.23.234")
        expect(sheet[1][13]).to eq("USD")
        expect(sheet[2][13]).to eq("CA")
        expect(sheet[1][14]).to eq(10)
        expect(sheet[2][14]).to eq(10)
        expect(sheet[1][15]).to eq(3.0)
        expect(sheet[2][15]).to eq(4.0)
        expect(sheet[1][16]).to eq(1.0)
        expect(sheet[2][16]).to eq(2.0)
        expect(sheet[1][17]).to eq(1.0)
        expect(sheet[2][17]).to eq(2.0)
        expect(sheet[1][18]).to eq(-100.0)
        expect(sheet[2][18]).to eq(-200.0)
        expect(sheet[1][19]).to eq(-96.0)
        expect(sheet[2][19]).to eq(-194.0)
        expect(sheet[1][20]).to eq(300.0)
        expect(sheet[2][20]).to eq(400.0)
        expect(sheet[1][21]).to eq(100.0)
        expect(sheet[2][21]).to eq(200.0)
      end

      it "sends email if address provided" do
        FiscalMonth.create!(company_id: canada.id, year: 2019, month_number: 1, start_date: Date.new(2018, 12, 15), end_date: Date.new(2019, 1, 14))

        Timecop.freeze(Date.new(2019, 9, 30)) do
          described_class.run_report(u, {'fiscal_month' => '2019-01', 'company' => 'PVHCANADA', 'email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk']})
        end

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq(['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'])
        expect(mail.subject).to eq("PVHCANADA Data Dump")
        expect(mail.body).to include("Attached is the &quot;PVHCANADA Data Dump Report, 2019-1&quot; based on CADEX Acceptance Date.")
        expect(mail.attachments.count).to eq(1)

        reader = XlsxTestReader.new(StringIO.new(mail.attachments[0].read)).raw_workbook_data
        expect(reader.length).to eq 1
      end
    end
  end

  describe "run_schedulable" do
    it "calls run report method if configured day of fiscal month" do
      settings = {'email' => ['a@b.com'] }
      current_fiscal_month = instance_double("current fiscal month")
      expect(described_class).to receive(:run_if_configured).with(settings).and_yield(current_fiscal_month, instance_double("fiscal date"))
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:run_data_dump_report).with(settings, current_fiscal_month: current_fiscal_month).and_return "success"

      expect(described_class.run_schedulable(settings)).to eq("success")
    end

    it "does not call run report method if wrong day of fiscal month" do
      settings = {'email' => ['a@b.com'] }
      # Does not yield.
      expect(described_class).to receive(:run_if_configured).with(settings)
      expect(subject).not_to receive(:run_data_dump_report)

      expect(described_class.run_schedulable(settings)).to be_nil
    end

    it "raises an exception if blank email param is provided" do
      expect(described_class).not_to receive(:new)

      expect { described_class.run_schedulable({'email' => [] }) }.to raise_error("Scheduled instances of the PVH / PVH Canada Duty Assist Report must " +
                                                                                  "include an email setting with at least one email address.")
    end

    it "raises an exception if no email param is provided" do
      expect(described_class).not_to receive(:new)

      expect { described_class.run_schedulable({}) }.to raise_error("Scheduled instances of the PVH / PVH Canada " +
                                                                    "Duty Assist Report must include an email setting with at least one email address.")
    end
  end
end
