describe OpenChain::Report::AscenaEntryAuditReport do

  let(:report) { described_class.new }
  let(:co) { with_customs_management_id FactoryBot(:importer, name: "Ascena", system_code: "ASCENA"), "ASCE" }
  let(:date_1) { DateTime.new(2016, 03, 15) }
  let(:date_2) { DateTime.new(2016, 03, 16) }
  let(:date_3) { DateTime.new(2016, 03, 17) }
  let(:date_4) { DateTime.new(2016, 03, 18) }
  let(:date_5) { DateTime.new(2016, 03, 19) }
  let(:cdefs) { described_class.prep_custom_definitions [:ord_selling_agent, :ord_type, :ord_line_wholesale_unit_price, :prod_reference_number] }

  let(:header) { ['Broker Reference', 'Entry Number', 'Entry Type', 'First Release Date', 'First Summary Sent Date', 'Entry Filed Date', 'Final Statement Date', 'Release Date', 'Duty Due Date', 'Mode of Transport', 'Master Bills', 'House Bills', 'Port of Unlading Code', 'Port of Entry Name', 'Port of Lading Code', 'Container Count', 'PO Number', 'Product Line', 'Part Number', 'Importer Tax ID', 'Customer Name', 'Invoice Number', 'Country Origin Code', 'Country Export Code', 'Department', 'HTS Code', 'Duty Rate', 'MID', 'MID Supplier Name', 'Vendor Name', 'Vendor Number', 'AGS Office', 'Subheader Number', 'Line Number', 'Customs Line Number', 'Units', 'UOM', 'SPI - Primary', 'Quantity 1', 'Quantity 2', 'UOM 1', 'UOM 2', 'ADD Case Number', 'Invoice Value - Brand', 'Invoice Value - 7501', 'Invoice Value - Contract', 'Entered Value', 'Rounded Entered Value', 'Total Duty', 'MPF - Prorated', 'MPF - Full', 'HMF', 'Total Fees', 'ADD Value', 'CVD Value', 'Excise Amount', 'Cotton Fee', 'Total Duty + Fees', 'Inv Non-Dutiable Amount', 'Inv Ln Non-Dutiable Amount', 'Total Non-Dutiable Amount', 'Unit Price - Brand', 'Unit Price - PO', 'Unit Price - 7501', 'Duty Savings - NDC', 'Duty Savings - First Sale', 'First Sale Flag', 'Related Parties', 'Fiscal Month', 'Fiscal Year', 'Vessel/Airline', 'Voyage/Flight', 'Web Link'] }

  def create_data
    vend = FactoryBot(:company, name: "vend name", system_code: "vend sys code")
    fact = FactoryBot(:company, name: "fact name", system_code: "fact sys code")
    @ent = FactoryBot(:entry, customer_number: 'ASCE', broker_reference: 'brok ref', entry_number: 'ent num', entry_type: 'ent type', first_release_date: date_1,
                   first_entry_sent_date: date_2, entry_filed_date: date_3, final_statement_date: date_4, release_date: date_5, duty_due_date: date_5, transport_mode_code: 'transport mode',
                   master_bills_of_lading: 'mbols', house_bills_of_lading: 'hbols', unlading_port_code: 'unlading', lading_port_code: 'lading', importer_tax_id: 'imp tax',
                   customer_name: 'cust name', total_non_dutiable_amount: 1, source_system: 'Alliance', entry_port_code: '0123', fiscal_month: 9, fiscal_year: 2017,
                   vessel: "HMS Pinafore", voyage: "Silk Road")
    ci = FactoryBot(:commercial_invoice, entry: @ent, invoice_number: 'inv num', invoice_value: 1, non_dutiable_amount: 2)
    @cil = FactoryBot(:commercial_invoice_line, commercial_invoice: ci, po_number: 'po num', part_number: "part num", product_line: 'prod line', country_origin_code: 'coo',
                   country_export_code: 'export code', department: 'dept', mid: 'mid', subheader_number: 1, line_number: 2,
                   customs_line_number: 3, quantity: 1, unit_of_measure: 'uom', add_case_number: 'add case', value: 18, prorated_mpf: 3, mpf: 4, hmf: 5,
                   add_case_value: 6, cvd_case_value: 7, cotton_fee: 8, non_dutiable_amount: 9, unit_price: 10, contract_amount: 20, related_parties: true)
    @cit = FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: @cil, hts_code: 'hts', duty_rate: 1, spi_primary: 'spi', classification_qty_1: 2,
                    classification_qty_2: 3, classification_uom_1: 'class uom 1', classification_uom_2: 'class uom 2', entered_value: 4, entered_value_7501:4,
                    excise_amount: 5, duty_amount: 6)
    @cit_2 = FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: @cil, hts_code: 'hts2', duty_rate: 2, spi_primary: 'spi2', classification_qty_1: 3,
                     classification_qty_2: 4, classification_uom_1: 'class uom 1(2)', classification_uom_2: 'class uom 2(2)', entered_value: 5, entered_value_7501: 5, excise_amount: 6,
                     duty_amount: 7)
    FactoryBot(:port, name: 'fenix port', cbsa_port: '0123')
    FactoryBot(:port, name: 'alliance port', schedule_d_code: '0123')
    FactoryBot(:container, entry: @ent)
    @prod = FactoryBot(:product, unique_identifier: 'ASCENA-part num')
    @ord = FactoryBot(:order, order_number: 'ASCENA-prod line-po num', vendor: vend, factory: fact)
    @ord.find_and_set_custom_value(cdefs[:ord_type], 'AGS')
    @ord.find_and_set_custom_value(cdefs[:ord_selling_agent], 'agent')
    @ord.save!
    ordln = FactoryBot(:order_line, order: @ord, product: @prod, price_per_unit: 1)
    ordln.update_custom_value!(cdefs[:ord_line_wholesale_unit_price], 2)
  end

  describe "permissions" do
    subject { described_class }

    let(:helper) { OpenChain::CustomHandler::Ascena::AscenaReportHelper }
    let! (:ascena) { with_customs_management_id(FactoryBot(:importer, name: "Ascena", system_code: "ASCENA"), "ASCE") }
    let! (:ann) { with_customs_management_id(FactoryBot(:importer, name: "Ann"), "ATAYLOR") }
    let! (:maurices) { with_customs_management_id(FactoryBot(:importer, name: "Maurices"), "MAUR") }
    let! (:ascena_master) { with_customs_management_id(FactoryBot(:importer, name: "Ascena Master"), "ASCENAMASTER") }
    let! (:user) { FactoryBot(:master_user) }
    let!(:ms) do
      m = stub_master_setup
      allow(m).to receive(:custom_feature?).with("Ascena Reports").and_return true
      allow(user).to receive(:view_entries?).and_return true
      m
    end

    let!(:cust_descriptions) {[{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"},
                               {cust_num: "ATAYLOR", sys_code: "ATAYLOR", name: "ANN TAYLOR INC", short_name: "Ann"},
                               {cust_num: "MAUR", sys_code: "MAUR", name: "MAURICES", short_name: "Maurices"}]}

    it "returns empty if 'Ascena Reports' custom feature absent" do
      allow(ms).to receive(:custom_feature?).with("Ascena Reports").and_return false
      expect(subject.permissions user).to be_empty
    end

    it "returns empty if user can't view entries" do
      allow(user).to receive(:view_entries?).and_return false
      expect(subject.permissions user).to be_empty
    end

    it "returns info for Ascena, Ann, Maurices if master user" do
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns info for Ascena, Ann, Maurices if user belongs to ASCENAMASTER" do
      user.company = ascena_master; user.company.save!
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns info for Ascena, Ann, Maurices if user belongs to ASCE_TRADE_ASSOC group" do
      user.company.update master: false
      g = FactoryBot(:group, system_code: "ASCE_TRADE_ASSOC")
      user.groups << g
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns only info for user's company if user doesn't belong to privileged category" do
      user.company = ascena; user.company.save!
      expect(subject.permissions user).to eq([{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"}])
    end

    it "omits info for missing company" do
      maurices.destroy
      expect(subject.permissions user).to eq([{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"},
                                              {cust_num: "ATAYLOR", sys_code: "ATAYLOR", name: "ANN TAYLOR INC", short_name: "Ann"}])
    end
  end

  describe "run_report" do
    let(:u) { FactoryBot(:user, time_zone: "Eastern Time (US & Canada)", company: co) }
    after { @temp.close if @temp }

    it "generates spreadsheet based on release_date, adjusts for user time zone" do
      create_data
      stub_master_setup
      @temp = described_class.run_report(u, {'start_release_date' => '2016-03-14', 'end_release_date' => '2016-03-20', 'range_field' => 'first_release_date', 'cust_number' => 'ASCE'})
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

    it "generates spreadsheet based on fiscal_date" do
      create_data
      @ent.update_attributes(fiscal_date: '2016-12-11', release_date: nil)
      FactoryBot(:fiscal_month, company: co, year: 2016, month_number: 11, start_date: '2016-11-05', end_date: '2016-12-10')
      FactoryBot(:fiscal_month, company: co, year: 2017, month_number: 2, start_date: '2017-02-07', end_date: '2017-03-06')
      stub_master_setup
      @temp = described_class.run_report(u, {'start_fiscal_year_month' => '2016-11', 'end_fiscal_year_month' => '2017-02', 'range_field' => 'fiscal_date', 'cust_number' => 'ASCE'})
      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 3
    end

  end

  describe "get_dates" do
    let(:u) { FactoryBot(:user, time_zone: "Eastern Time (US & Canada)") }

    it "extracts/converts month and year args to the right fiscal_date when range_field is 'fiscal_date'" do
      FactoryBot(:fiscal_month, company: co, year: 2016, month_number: 11, start_date: '2016-11-05', end_date: '2016-12-10')
      FactoryBot(:fiscal_month, company: co, year: 2017, month_number: 2, start_date: '2017-02-07', end_date: '2017-03-06')
      start_date, end_date = report.get_dates(u, {'range_field' => 'fiscal_date', 'start_fiscal_year_month' => '2016-11', 'start_fiscal_year' => '2016', 'end_fiscal_year_month' => '2017-02'})
      expect(start_date).to eq "2016-11-05"
      expect(end_date).to eq "2017-02-07"
    end

    it "returns time-zone-adjusted start_date and end_date args when range_field is 'release_date'" do
      start_date, end_date = report.get_dates(u, {'range_field' => 'first_release_date', 'start_release_date' => '2016-03-14', 'end_release_date' => '2016-03-20'})
      expect(start_date).to eq "2016-03-14 04:00:00"
      expect(end_date).to eq "2016-03-20 04:00:00"
    end
  end

  describe "query" do
    before { create_data }

    it "produces expected results for Ascena" do
      result = ActiveRecord::Base.connection.exec_query(report.query '2016-03-14', '2016-03-20', 'release_date', 'ASCENA', cdefs)
      expect(result.columns).to eq header
      expect(result.count).to eq 2
      rows = []
      result.each { |r| rows << r }

      expect(rows[0]).to eq(
        {'Broker Reference'=>'brok ref', 'Entry Number'=>'ent num', 'Entry Type'=>'ent type', 'First Release Date'=>date_1,
         'First Summary Sent Date'=>date_2, 'Entry Filed Date'=>date_3, 'Final Statement Date'=>date_4,
         'Release Date'=>date_5, 'Duty Due Date' => date_5, 'Mode of Transport'=>'transport mode', 'Master Bills'=>'mbols', 'House Bills'=>'hbols',
         'Port of Unlading Code'=>'unlading', 'Port of Entry Name'=>'alliance port', 'Port of Lading Code'=>'lading', 'Container Count' => 1, 'PO Number'=>'po num',
         'Product Line'=>'prod line', 'Part Number'=>'part num', 'Importer Tax ID'=>'imp tax', 'Customer Name'=>'cust name', 'Invoice Number'=>'inv num',
         'Country Origin Code'=>'coo', 'Country Export Code'=>'export code', 'Department'=>'dept', 'HTS Code'=>'hts', 'Duty Rate'=>1, 'MID'=>'mid',
         'MID Supplier Name' => 'fact name', 'Vendor Name'=>'vend name', 'Vendor Number'=>'vend sys code', 'AGS Office'=>'agent', 'Subheader Number'=>1,
         'Line Number'=>2, 'Customs Line Number'=>3, 'Units'=>1, 'UOM'=>'uom', 'SPI - Primary'=>'spi', 'Quantity 1'=>2, 'Quantity 2'=>3, 'UOM 1'=>'class uom 1',
         'UOM 2'=>'class uom 2', 'ADD Case Number'=>'add case', 'Invoice Value - Brand'=>2, 'Invoice Value - 7501'=>18, 'Invoice Value - Contract'=>20,
         'Entered Value'=>4, 'Rounded Entered Value'=>4, 'Total Duty'=>13, 'MPF - Prorated'=>3, 'MPF - Full'=>4, 'HMF'=>5, 'Total Fees'=>16, 'ADD Value'=>6,
         'CVD Value'=>7, 'Excise Amount'=>5, 'Cotton Fee'=>8, 'Total Duty + Fees'=>29, 'Inv Non-Dutiable Amount'=>2, 'Inv Ln Non-Dutiable Amount'=>9,
         'Total Non-Dutiable Amount'=>1, 'Unit Price - Brand'=>2, 'Unit Price - PO'=>1, 'Unit Price - 7501'=>18, 'Duty Savings - NDC'=>13,
         'Duty Savings - First Sale' => 3, 'First Sale Flag'=>'Y', 'Related Parties'=>'Y', 'Fiscal Month'=>9, 'Fiscal Year'=>2017, 'Vessel/Airline' => 'HMS Pinafore',
         'Voyage/Flight' => 'Silk Road', 'Web Link'=>@ent.id})

      expect(rows[1]).to eq(
        {'Broker Reference'=>'brok ref', 'Entry Number'=>'ent num', 'Entry Type'=>'ent type', 'First Release Date'=>date_1, 'First Summary Sent Date'=>date_2,
         'Entry Filed Date'=>date_3, 'Final Statement Date'=>date_4, 'Release Date'=>date_5, 'Duty Due Date'=>date_5, 'Mode of Transport'=>'transport mode', 'Master Bills'=>'mbols',
         'House Bills'=>'hbols', 'Port of Unlading Code'=>'unlading', 'Port of Entry Name'=>'alliance port', 'Port of Lading Code'=>'lading', 'Container Count' => 1,
         'PO Number'=>'po num', 'Product Line'=>'prod line', 'Part Number'=>'part num', 'Importer Tax ID'=>'imp tax', 'Customer Name'=>'cust name', 'Invoice Number'=>'inv num',
         'Country Origin Code'=>'coo', 'Country Export Code'=>'export code', 'Department'=>'dept', 'HTS Code'=>'hts2', 'Duty Rate'=>2, 'MID'=>'mid',
         'MID Supplier Name' => 'fact name', 'Vendor Name'=>'vend name', 'Vendor Number'=>'vend sys code', 'AGS Office'=>'agent', 'Subheader Number'=>1,
         'Line Number'=>2, 'Customs Line Number'=>3, 'Units'=>1, 'UOM'=>'uom', 'SPI - Primary'=>'spi2', 'Quantity 1'=>3, 'Quantity 2'=>4,
         'UOM 1'=>'class uom 1(2)', 'UOM 2'=>'class uom 2(2)', 'ADD Case Number'=>'add case', 'Invoice Value - Brand'=>2, 'Invoice Value - 7501'=>18,
         'Invoice Value - Contract'=>20, 'Entered Value'=>5, 'Rounded Entered Value'=>5, 'Total Duty'=>13, 'MPF - Prorated'=>3.0, 'MPF - Full'=>4, 'HMF'=>5,
         'Total Fees'=>16, 'ADD Value'=>6, 'CVD Value'=>7, 'Excise Amount'=>6, 'Cotton Fee'=>8, 'Total Duty + Fees'=>29, 'Inv Non-Dutiable Amount'=>2,
         'Inv Ln Non-Dutiable Amount'=>9, 'Total Non-Dutiable Amount'=>1, 'Unit Price - Brand'=>2, 'Unit Price - PO'=>1, 'Unit Price - 7501'=>18, 'Duty Savings - NDC'=>13,
         'Duty Savings - First Sale' => 3, 'First Sale Flag'=>'Y', 'Related Parties'=>'Y', 'Fiscal Month'=>9, 'Fiscal Year'=>2017, 'Vessel/Airline' => 'HMS Pinafore',
         'Voyage/Flight' => 'Silk Road', 'Web Link'=>@ent.id}
        )
    end

    it "produces expected results for Ann Inc" do
      @ent.update_attributes(customer_number: 'ATAYLOR')
      @ord.update_attributes(order_number: 'ATAYLOR-po num')
      @prod.update_attributes(unique_identifier: 'ATAYLOR-part num')

      result = ActiveRecord::Base.connection.exec_query(report.query '2016-03-14', '2016-03-20', 'release_date', 'ATAYLOR', cdefs)
      expect(result.columns).to eq header
      expect(result.count).to eq 2
      # check order join
      expect(result.first["Vendor Name"]).to eq "vend name"
    end

    it "produces expected results for Maurices" do
      @ent.update_attributes(customer_number: 'MAUR')
      @ord.update_attributes(order_number: 'ASCENA-MAU-po num')
      @prod.update_attributes(unique_identifier: 'ASCENA-part num')

      result = ActiveRecord::Base.connection.exec_query(report.query '2016-03-14', '2016-03-20', 'release_date', 'MAUR', cdefs)
      expect(result.columns).to eq header
      expect(result.count).to eq 2

      # helper fields with MAUR-specific behavior
      expect(result.first['Unit Price - Brand']).to eq 2
      expect(result.first['Unit Price - PO']).to eq 1
      expect(result.first['Invoice Value - Brand']).to eq 2

      # check order join
      expect(result.first["Vendor Name"]).to eq "vend name"
    end

    it "skips entries whose release date isn't in the range" do
      result = ActiveRecord::Base.connection.execute(report.query '2016-04-1', '2016-04-2', 'release_date', 'ASCENA', cdefs)
      expect(result.count).to eq 0
    end

    it "skips entries that don't have customer number 'ASCE'" do
      @ent.update_attributes(customer_number: "FOO")
      result = ActiveRecord::Base.connection.execute(report.query '2016-03-14', '2016-03-20', 'release_date', 'ASCENA', cdefs)
      expect(result.count).to eq 0
    end

    it "selects port based on entry's source_system field" do
      @ent.update_attributes(source_system: "FENIX")
      result = ActiveRecord::Base.connection.exec_query(report.query '2016-03-14', '2016-03-20', 'release_date', 'ASCENA', cdefs)
      expect(result.first['Port of Entry Name']).to eq "fenix port"
    end

    it "For non-AGS orders, returns a blank/0 for AGS Office" do
      @ord.update_custom_value!(cdefs[:ord_type], 'NONAGS')
      result = ActiveRecord::Base.connection.exec_query(report.query '2016-03-14', '2016-03-20', 'release_date', 'ASCENA', cdefs)
      row = result.first
      expect(row['AGS Office']).to be_blank
    end

    it "assigns 0 to 'Duty Savings - First Sale', 'N' to First Sale Flag if contract amount is 0" do
      @cil.update_attributes(contract_amount: 0)
      result = ActiveRecord::Base.connection.exec_query(report.query '2016-03-14', '2016-03-20', 'release_date', 'ASCENA', cdefs)
      row = result.first
      expect(row['First Sale Flag']).to eq 'N'
      expect(row['Duty Savings - First Sale']).to eq 0
    end

    it "assigns 0 to Duty Savings - NDC if total entered value is 0" do
      @cit.update_attributes(entered_value: 0)
      @cit_2.update_attributes(entered_value: 0)
      result = ActiveRecord::Base.connection.exec_query(report.query '2016-03-14', '2016-03-20', 'release_date', 'ASCENA', cdefs)
      expect(result.first['Duty Savings - NDC']).to eq 0
    end

    it "assigns 0 to Duty Savings - NDC if result of calculation is less than 0" do
      @cit.update_attributes(entered_value: 1000)
      result = ActiveRecord::Base.connection.exec_query(report.query '2016-03-14', '2016-03-20', 'release_date', 'ASCENA', cdefs)
      expect(result.first['Duty Savings - NDC']).to eq 0
    end
  end


end
