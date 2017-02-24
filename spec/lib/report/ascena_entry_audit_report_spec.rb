require 'spec_helper'

describe OpenChain::Report::AscenaEntryAuditReport do

  let(:report) { described_class.new }
  let(:co) { Factory(:company, system_code: "ASCENA")}
  let(:date_1) { DateTime.new(2016,03,15) }
  let(:date_2) { DateTime.new(2016,03,16) }
  let(:date_3) { DateTime.new(2016,03,17) }
  let(:date_4) { DateTime.new(2016,03,18) }
  let(:date_5) { DateTime.new(2016,03,19) }
  let(:cdefs) { described_class.prep_custom_definitions [:ord_selling_agent, :ord_type, :prod_part_number] }
  let(:header) { ['Broker Reference', 'Entry Number', 'Entry Type', 'First Release Date', 'First Summary Sent Date', 'Entry Filed Date', 
                  'Final Statement Date', 'Release Date', 'Mode of Transport', 'Master Bills', 'House Bills', 'Port of Unlading Code', 
                  'Port of Entry Name', 'Port of Lading Code', 'PO Number', 'Product Line', 'Part Number', 'Importer Tax ID', 'Customer Name', 
                  'Invoice Number', 'Country Origin Code', 'Country Export Code', 'Department', 'HTS Code', 'Duty Rate', 'MID', 'Vendor Name', 
                  'Vendor Number', 'AGS Office', 'Subheader Number', 'Line Number', 'Customs Line Number', 'Units', 'UOM', 
                  'SPI - Primary', 'Quantity 1', 'Quantity 2', 'UOM 1', 'UOM 2', 'ADD Case Number', 'Value', 'Invoice Value', 'Entered Value', 
                  'Total Duty', 'MPF - Prorated', 'MPF - Full', 'HMF', 'Total Fees', 'ADD Value', 'CVD Value', 'Excise Amount', 'Cotton Fee', 
                  'Total Duty + Fees', 'Inv Non-Dutiable Amount', 'Inv Ln Non-Dutiable Amount', 'Total Non-Dutiable Amount', 'Price to Brand', 
                  'Vendor Price to AGS', 'First Sale Price', 'First Sale Duty Savings', 'First Sale Flag'] }

  def create_data
    vend = Factory(:company, name: "vend name", system_code: "vend sys code")
    @ent = Factory(:entry, customer_number: 'ASCE', broker_reference: 'brok ref', entry_number: 'ent num', entry_type: 'ent type', first_release_date: date_1, 
                   first_entry_sent_date: date_2, entry_filed_date: date_3, final_statement_date: date_4, release_date: date_5, transport_mode_code: 'transport mode', 
                   master_bills_of_lading: 'mbols', house_bills_of_lading: 'hbols', unlading_port_code: 'unlading', lading_port_code: 'lading', importer_tax_id: 'imp tax', 
                   customer_name: 'cust name', total_non_dutiable_amount: 1, source_system: 'Alliance', entry_port_code: '0123')
    @ci = Factory(:commercial_invoice, entry: @ent, invoice_number: 'inv num', invoice_value: 1, non_dutiable_amount: 2)
    @cil = Factory(:commercial_invoice_line, commercial_invoice: @ci, po_number: 'po num', part_number: "part num", product_line: 'prod line', country_origin_code: 'coo', 
                   country_export_code: 'export code', department: 'dept', mid: 'mid', subheader_number: 1, line_number: 2,
                   customs_line_number: 3, quantity: 1, unit_of_measure: 'uom', add_case_number: 'add case', value: 18, prorated_mpf: 3, mpf: 4, hmf: 5, 
                   add_case_value: 6, cvd_case_value: 7, cotton_fee: 8, non_dutiable_amount: 9, unit_price: 10, contract_amount: 20)
    @cit = Factory(:commercial_invoice_tariff, commercial_invoice_line: @cil, hts_code: 'hts', duty_rate: 1, spi_primary: 'spi', classification_qty_1: 2,
                    classification_qty_2: 3, classification_uom_1: 'class uom 1', classification_uom_2: 'class uom 2', entered_value: 4,
                    excise_amount: 5, duty_amount: 6)
    @cit_2 = Factory(:commercial_invoice_tariff, commercial_invoice_line: @cil, hts_code: 'hts2', duty_rate: 2, spi_primary: 'spi2', classification_qty_1: 3,
                     classification_qty_2: 4, classification_uom_1: 'class uom 1(2)', classification_uom_2: 'class uom 2(2)', entered_value: 5, excise_amount: 6, 
                     duty_amount: 7)
    Factory(:port, name: 'fenix port', cbsa_port: '0123')
    Factory(:port, name: 'alliance port', schedule_d_code: '0123')
    @prod = Factory(:product, unique_identifier: 'ASCENA-part num')
    @ord = Factory(:order, order_number: 'ASCENA-po num', vendor: vend)
    @ord.find_and_set_custom_value(cdefs[:ord_type], 'AGS')
    @ord.find_and_set_custom_value(cdefs[:ord_selling_agent], 'agent')
    @ord.save!
    @ordln = Factory(:order_line, order: @ord, product: @prod, price_per_unit: 1)
  end

  describe "permission?" do
    before do
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return "www-vfitrack-net"
    end

    it "allows access for master users who can view entries" do
      u = Factory(:master_user)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "allows access for Ascena users who can view entries" do
      co = Factory(:company, system_code: "ASCENA")
      u = Factory(:user, company: co)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "allows access for users of Ascena's parent companies" do
      ascena = Factory(:company, system_code: "ASCENA")
      parent = Factory(:company, linked_companies: [ascena])
      u = Factory(:user, company: parent)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "prevents access by other companies" do
      u = Factory(:user)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who can't view entries" do
      u = Factory(:master_user)
      expect(u).to receive(:view_entries?).and_return false
      expect(described_class.permission? u).to eq false
    end
  end

  describe "run_report" do
    let(:u) { Factory(:user, time_zone: "Eastern Time (US & Canada)", company: co) }
    after { @temp.close if @temp }

    it "generates spreadsheet, adjusts for user time zone" do
      create_data
      stub_master_setup
      adjusted_start = "2016-03-14 05:00:00"
      adjusted_end = "2016-03-20 05:00:00"
      @temp = described_class.run_report(u, {'start_date' => '2016-03-14', 'end_date' => '2016-03-20'})
      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]
      
      expect(sheet.name).to eq "Ascena Entry Audit Report"
      expect(sheet.rows.count).to eq 3
      expect(sheet.row(0)).to eq header
      expect(sheet.row(1)[3]).to eq(date_1.in_time_zone(u.time_zone).to_s)
      expect(sheet.row(1)[4]).to eq(date_2.in_time_zone(u.time_zone).to_s)
      expect(sheet.row(1)[5]).to eq(date_3.in_time_zone(u.time_zone).to_s)
      expect(sheet.row(1)[7]).to eq(date_5.in_time_zone(u.time_zone).to_s)
    end
  end

  describe "query" do
    before { create_data }
    
    it "produces expected results" do
      result = ActiveRecord::Base.connection.execute(report.query '2016-03-14', '2016-03-20', cdefs)
      expect(result.fields).to eq header
      expect(result.count).to eq 2
      rows = []
      result.each { |r| rows << r }
      expect(rows[0]).to eq ['brok ref', 'ent num', 'ent type', date_1, date_2, date_3, date_4, date_5, 'transport mode', 'mbols', 'hbols', 'unlading', 
                             'alliance port', 'lading', 'po num', 'prod line', 'part num', 'imp tax', 'cust name', 'inv num', 'coo', 'export code',
                             'dept', 'hts', 1, 'mid', 'vend name', 'vend sys code', 'agent', 1, 2, 3, 1, 'uom', 'spi', 2, 3, 'class uom 1', 'class uom 2', 
                             'add case', 18, 1, 4, 13, 3, 4, 5, 16, 6, 7, 5, 8, 29, 2, 9, 1, 10, 1, 4, 13, 'Y']
      
      expect(rows[1]).to eq ['brok ref', 'ent num', 'ent type', date_1, date_2, date_3, date_4, date_5, 'transport mode', 'mbols', 'hbols', 'unlading', 
                             'alliance port', 'lading', 'po num', 'prod line', 'part num', 'imp tax', 'cust name', 'inv num', 'coo', 'export code',
                             'dept', 'hts2', 2, 'mid', 'vend name', 'vend sys code', 'agent', 1, 2, 3, 1, 'uom', 'spi2', 3, 4, 'class uom 1(2)', 'class uom 2(2)', 
                             'add case', 18, 1, 5, 13, 3, 4, 5, 16, 6, 7, 6, 8, 29, 2, 9, 1, 10, 1, 5, 13, 'Y']
    end

    it "skips entries whose release date isn't in the range" do
      result = ActiveRecord::Base.connection.execute(report.query '2016-04-1', '2016-04-2', cdefs)
      expect(result.count).to eq 0
    end

    it "skips entries that don't have customer number 'ASCE'" do
      @ent.update_attributes(customer_number: "FOO")
      result = ActiveRecord::Base.connection.execute(report.query '2016-03-14', '2016-03-20', cdefs)
      expect(result.count).to eq 0
    end

    it "selects port based on entry's source_system field" do
      @ent.update_attributes(source_system: "FENIX")
      result = ActiveRecord::Base.connection.execute(report.query '2016-03-14', '2016-03-20', cdefs)
      expect(result.first[12]).to eq "fenix port"
    end

    it "For non-AGS orders, returns a blank/0 for AGS Office, Vendor Price to AGS, First Sale Price" do
      @ord.update_custom_value!(cdefs[:ord_type], 'NONAGS')
      result = ActiveRecord::Base.connection.execute(report.query '2016-03-14', '2016-03-20', cdefs)
      row = result.first
      expect(row[28]).to be_blank
      expect(row[57]).to eq 0
      expect(row[58]).to eq 0
    end

    it "assigns 0 to First Sale Price and 'N' to First Sale Flag if contract amount is 0" do
      @cil.update_attributes(contract_amount: 0)
      result = ActiveRecord::Base.connection.execute(report.query '2016-03-14', '2016-03-20', cdefs)
      row = result.first
      expect(row[58]).to eq 0
      expect(row[60]).to eq 'N'
    end

    it "assigns 0 to First Sale Duty Savings if total entered value is 0" do
      @cit.update_attributes(entered_value: 0)
      @cit_2.update_attributes(entered_value: 0)
      result = ActiveRecord::Base.connection.execute(report.query '2016-03-14', '2016-03-20', cdefs)
      expect(result.first[59]).to eq 0
    end

    it "assigns 0 to First Sale Duty Savings if result of calculation is less than 0" do
      @cit.update_attributes(entered_value: 1000)
      result = ActiveRecord::Base.connection.execute(report.query '2016-03-14', '2016-03-20', cdefs)
      expect(result.first[59]).to eq 0
    end
  end


end