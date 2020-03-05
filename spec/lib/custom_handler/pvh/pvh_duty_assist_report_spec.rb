require 'open_chain/custom_handler/vfitrack_custom_definition_support'
class DummyClass
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
end

describe OpenChain::CustomHandler::Pvh::PvhDutyAssistReport do

  let!(:canada) { with_fenix_id(Factory(:importer, name: 'PVH Canada'), '833231749RM0001') }
  let!(:us) { with_customs_management_id(Factory(:importer, name: 'PVH', system_code: 'PVH'), "PVH") }

  subject { described_class }

  def setup_data(customer_number, company)
    cdefs = DummyClass.prep_custom_definitions([:prod_part_number])
    entry1 = Factory(:entry, entry_number: 'entry1', master_bills_of_lading: "1234\n",
                     transport_mode_code: "Ocean", customer_number: customer_number, fiscal_year: 2020,
                     fiscal_month: 1, entry_filed_date: DateTime.parse("02/02/2020 10:45"), release_date: DateTime.parse("02/02/2020 10:45"),
                     import_date: Date.parse("02/02/2020"), arrival_date: Date.parse("02/02/2020"), across_sent_date: Date.parse("04/02/2020"))
    entry2 = Factory(:entry, entry_number: 'entry2', master_bills_of_lading: "2345\n",
                     transport_mode_code: "Ocean", customer_number: customer_number, fiscal_year: 2020,
                     fiscal_month: 1, entry_filed_date: DateTime.parse("02/02/2020 10:45"), release_date: DateTime.parse("02/02/2020 10:45"),
                     import_date: Date.parse("02/02/2020"), arrival_date: Date.parse("02/02/2020"), across_sent_date: Date.parse("03/02/2020"))
    Factory(:broker_invoice, entry: entry1)
    Factory(:broker_invoice, entry: entry2)
    ci1 = Factory(:commercial_invoice, entry: entry1, invoice_number: "invoice1", exchange_rate: "10", currency: "USD")
    ci2 = Factory(:commercial_invoice, entry: entry2, invoice_number: "invoice2", exchange_rate: "10", currency: "CA")
    prod1 = Factory(:product)
    prod2 = Factory(:product)
    prod1.find_and_set_custom_value(cdefs[:prod_part_number], 'abcd')
    prod1.save
    prod2.find_and_set_custom_value(cdefs[:prod_part_number], 'efgh')
    prod2.save
    cil1 = Factory(:commercial_invoice_line, commercial_invoice: ci1, part_number: 'abcd', country_origin_code: 'Line1CO',
                   po_number: "PO1", value_foreign: "1.00", add_to_make_amount: "1.00", contract_amount: "1.00",
                   unit_price: "100", quantity: 1, value: 3.0, miscellaneous_discount: 100.00)
    cil2 = Factory(:commercial_invoice_line, commercial_invoice: ci2, part_number: 'efgh', country_origin_code: 'Line2CO',
                   po_number: "PO2", value_foreign: "2.00", add_to_make_amount: "2.00", contract_amount: "2.00",
                   unit_price: 200, quantity: 2, value: 4.0, miscellaneous_discount: 200.00)
    cit1 = Factory(:commercial_invoice_tariff, commercial_invoice_line: cil1, tariff_description: "Tariff One",
                   entered_value: "1.00", duty_rate: "3", hts_code: "123.12.123")
    cit2 = Factory(:commercial_invoice_tariff, commercial_invoice_line: cil2, tariff_description: "Tariff Two",
                   entered_value: "2.00", duty_rate: "4", hts_code: "234.23.234")
    cit3 = Factory(:commercial_invoice_tariff, commercial_invoice_line: cil1, tariff_description: "Tariff One",
                       entered_value: "1.00", duty_rate: "3", hts_code: "9903.12.123")
    cit4 = Factory(:commercial_invoice_tariff, commercial_invoice_line: cil2, tariff_description: "Tariff Two",
                   entered_value: "2.00", duty_rate: "4", hts_code: "9903.23.234")
    shipment1 = Factory(:shipment, master_bill_of_lading: entry1.master_bills_of_lading.gsub(/\n/, ''))
    shipment2 = Factory(:shipment, master_bill_of_lading: entry2.master_bills_of_lading.gsub(/\n/, ''))
    sl1 = Factory(:shipment_line, shipment: shipment1, product: prod1)
    sl2 = Factory(:shipment_line, shipment: shipment2, product: prod2)
    o1 = Factory(:order, importer: company)
    o2 = Factory(:order, importer: company)
    ol1 = Factory(:order_line, order: o1, product: prod1, line_number: 1)
    ol2 = Factory(:order_line, order: o2, product: prod2, line_number: 2)
    ps1 = PieceSet.create!(order_line: ol1, shipment_line: sl1, quantity: 1)
    ps2 = PieceSet.create!(order_line: ol2, shipment_line: sl2, quantity: 1)
  end


  describe "run_schedulable" do
    let!(:current_canada_fm) { Factory(:fiscal_month, company: canada, start_date: Date.new(2020,3,2), end_date: Date.new(2020, 4, 5), year: 2020, month_number: 2)}
    let!(:previous_canada_fm) { Factory(:fiscal_month, company: canada, start_date: Date.new(2020, 2, 3), end_date: Date.new(2020, 3, 1), year: 2020, month_number: 1)}
    let!(:current_us_fm) { Factory(:fiscal_month, company: us, start_date: Date.new(2020,3,2), end_date: Date.new(2020, 4, 5), year: 2020, month_number: 2)}
    let!(:previous_us_fm) { Factory(:fiscal_month, company: us, start_date: Date.new(2020, 2, 3), end_date: Date.new(2020, 3, 1), year: 2020, month_number: 1)}

    it "runs report for previous fiscal month for US" do
      setup_data("PVH", us)

      report = subject.new.run(2020, 1, 'PVH')

      Timecop.freeze(DateTime.new(2020,3,5,12,0)) do
        subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'],
                                'cust_number' => 'PVH',
                                'fiscal_day' => 3)

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq(['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'])
        expect(mail.subject).to eq("PVH Duty Assist 2020-1")
        expect(mail.body).to match(/Attached is the PVH Assist Report for 2020-1/)
        expect(mail.attachments.count).to eql(1)

        test_reader = XlsxTestReader.new(StringIO.new(mail.attachments[0].read)).raw_workbook_data
        sheet = test_reader["Results"]
        expect(sheet[0]).to eq(described_class.new.us_headers)
        expect(sheet[1][0]).to eq('entry1')
        expect(sheet[2][0]).to eq('entry2')
        expect(sheet[1][1]).to eq('invoice1')
        expect(sheet[2][1]).to eq('invoice2')
        expect(sheet[1][2]).to eq('Line1CO')
        expect(sheet[2][2]).to eq('Line2CO')
        expect(sheet[1][3]).to eq('PO1')
        expect(sheet[2][3]).to eq('PO2')
        expect(sheet[1][4]).to be_nil
        expect(sheet[2][4]).to be_nil
        expect(sheet[1][5]).to eq('2020-02-02 05:45:00.000000000 +0000')
        expect(sheet[2][5]).to eq('2020-02-02 05:45:00.000000000 +0000')
        expect(sheet[1][6]).to eq('2020-02-02 00:00:00.000000000 +0000')
        expect(sheet[2][6]).to eq('2020-02-02 00:00:00.000000000 +0000')
        expect(sheet[1][7]).to eq("Tariff One")
        expect(sheet[2][7]).to eq("Tariff Two")
        expect(sheet[1][8]).to eq("1234")
        expect(sheet[2][8]).to eq("2345")
        expect(sheet[1][9]).to eq("2020-02-01 18:59:59.000000000 +0000")
        expect(sheet[2][9]).to eq("2020-02-01 18:59:59.000000000 +0000")
        expect(sheet[1][10]).to eq(1.0)
        expect(sheet[2][10]).to eq(2.0)
        expect(sheet[1][11]).to eq(1.0)
        expect(sheet[2][11]).to eq(2.0)
        expect(sheet[1][12]).to eq(2.0)
        expect(sheet[2][12]).to eq(4.0)
        expect(sheet[1][13]).to eq(0.0)
        expect(sheet[2][13]).to eq(0.0)
        expect(sheet[1][14]).to eq(-0.0)
        expect(sheet[2][14]).to eq(-0.0)
        expect(sheet[1][15]).to eq(3.0)
        expect(sheet[2][15]).to eq(4.0)
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
        expect(sheet[1][21]).to eq(3.0)
        expect(sheet[2][21]).to eq(4.0)
      end

    end

    it "runs report for previous fiscal month for Canada" do
      setup_data("PVHCANADA", canada)

      report = subject.new.run(2020, 1, 'PVHCANADA')

      Timecop.freeze(DateTime.new(2020,3,5,12,0)) do
        subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'],
                                'cust_number' => 'PVHCANADA',
                                'fiscal_day' => 3)

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq(['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'])
        expect(mail.subject).to eq("PVHCANADA Duty Assist 2020-1")
        expect(mail.body).to match(/Attached is the PVHCANADA Assist Report for 2020-1/)
        expect(mail.attachments.count).to eql(1)

        test_reader = XlsxTestReader.new(StringIO.new(mail.attachments[0].read)).raw_workbook_data
        sheet = test_reader["Results"]
        expect(sheet[0]).to eql(described_class.new.ca_headers)
        expect(sheet[1][0]).to eq('entry1')
        expect(sheet[2][0]).to eq('entry2')
        expect(sheet[1][1]).to eq('invoice1')
        expect(sheet[2][1]).to eq('invoice2')
        expect(sheet[1][2]).to eq('PO1')
        expect(sheet[2][2]).to eq('PO2')
        expect(sheet[1][3]).to eq('1234')
        expect(sheet[2][3]).to eq('2345')
        expect(sheet[1][4]).to be_nil
        expect(sheet[2][4]).to be_nil
        expect(sheet[1][5]).to eq('2020-02-02 05:45:00.000000000 +0000')
        expect(sheet[2][5]).to eq('2020-02-02 05:45:00.000000000 +0000')
        expect(sheet[1][6]).to eq('2020-02-01 00:00:00.000000000 +0000')
        expect(sheet[2][6]).to eq('2020-02-01 00:00:00.000000000 +0000')
        expect(sheet[1][7]).to eq("2020-02-03 18:59:59.000000000 +0000")
        expect(sheet[2][7]).to eq("2020-02-02 18:59:59.000000000 +0000")
        expect(sheet[1][8]).to eq("2020-02-01 18:59:59.000000000 +0000")
        expect(sheet[2][8]).to eq("2020-02-01 18:59:59.000000000 +0000")
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
        expect(sheet[1][21]).to eq(-100.0)
        expect(sheet[2][21]).to eq(-200.0)
      end

    end
  end
end