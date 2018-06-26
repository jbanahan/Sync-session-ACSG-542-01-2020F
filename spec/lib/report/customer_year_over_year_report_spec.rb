describe OpenChain::Report::CustomerYearOverYearReport do

  describe "permission?" do
    let(:ms) { stub_master_setup }
    let (:u) { Factory(:user) }
    let (:group) { Group.use_system_group 'entry_yoy_report', create: true }

    it "allows access for users who can view entries, are subscribed to YoY report custom feature and are in YoY group" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("Entry Year Over Year Report").and_return true
      expect(u).to receive(:in_group?).with(group).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "prevents access by users who cannot view entries" do
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who are not subscribed to YoY report custom feature" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("Entry Year Over Year Report").and_return false
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who are not in the YoY group" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("Entry Year Over Year Report").and_return true
      expect(u).to receive(:in_group?).with(group).and_return false
      expect(described_class.permission? u).to eq false
    end
  end

  describe "run_report" do
    let (:u) { Factory(:user) }
    let(:importer) { Factory(:company, name:'Crudco Consumables and Poisons, Inc.', system_code:'CRUDCO') }

    after { @temp.close if @temp }

    def make_entry counter, entry_type, date_range_field, date_range_field_val
      entry = Factory(:entry, customer_number:'ABCD', customer_name:'Crudco', broker_reference:"brok ref #{counter}", summary_line_count:10,
              entry_type:entry_type, entered_value:55.55, total_duty:44.44, mpf:33.33, hmf:22.22, cotton_fee:11.11, total_taxes:9.99,
              other_fees:8.88, total_fees:7.77, arrival_date:make_utc_date(2018,1,1+counter), release_date:make_utc_date(2018,2,2+counter),
              file_logged_date:make_utc_date(2018,3,3+counter), fiscal_date:Date.new(2018,4,4+counter),
              eta_date:Date.new(2018,5,5+counter), total_units:543.2, total_gst:6.66, export_country_codes:'CN',
              transport_mode_code:'S', broker_invoice_total:12.34, importer_id:importer.id)
      entry.update_attributes date_range_field => date_range_field_val
      entry
    end

    it "generates spreadsheet based on arrival date" do
      ent_2016_Feb_1 = make_entry 1, '01', :arrival_date, make_utc_date(2016,2,16)
      ent_2016_Feb_2 = make_entry 2, '01', :arrival_date, make_utc_date(2016,2,17)
      ent_2016_Mar = make_entry 3, '02', :arrival_date, make_utc_date(2016,3,3)
      ent_2016_Apr_1 = make_entry 4, '01', :arrival_date, make_utc_date(2016,4,4)
      ent_2016_Apr_2 = make_entry 5, '02', :arrival_date, make_utc_date(2016,4,16)
      ent_2016_Apr_3 = make_entry 6, '01', :arrival_date, make_utc_date(2016,4,25)
      ent_2016_May = make_entry 7, '13', :arrival_date, make_utc_date(2016,5,15)
      ent_2016_Jun = make_entry 8, '02', :arrival_date, make_utc_date(2016,6,6)

      ent_2017_Jan_1 = make_entry 9, '01', :arrival_date, make_utc_date(2017,1,1)
      ent_2017_Jan_2 = make_entry 10, '01', :arrival_date, make_utc_date(2017,1,17)
      ent_2017_Mar = make_entry 11, '01', :arrival_date, make_utc_date(2017,3,2)
      ent_2017_Apr = make_entry 12, '01', :arrival_date, make_utc_date(2017,4,7)
      ent_2017_May_1 = make_entry 13, '01', :arrival_date, make_utc_date(2017,5,21)
      ent_2017_May_2 = make_entry 14, '01', :arrival_date, make_utc_date(2017,5,22)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 15, '01', :arrival_date, make_utc_date(2015,12,13)
      ent_2018_Feb = make_entry 16, '01', :arrival_date, make_utc_date(2018,2,8)

      # This should be excluded because it belongs to a different importer.
      ent_2016_Feb_different_importer = make_entry 17, '01', :arrival_date, make_utc_date(2016,2,11)
      importer_2 = Factory(:company, name:'Crudco Bitter Rival')
      ent_2016_Feb_different_importer.update_attributes :importer_id => importer_2.id

      Timecop.freeze(make_eastern_date(2017,6,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'arrival_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => true, 'include_taxes' => true, 'include_other_fees' => true})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_arrival_date_[2016_2017].xls'

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      # Tab name should have been truncated.  Company name is too long to fit.
      expect(sheet.name).to eq "Crudco Consumables an - REPORT"
      expect(sheet.rows.count).to eq 53
      expect(sheet.row(0)).to eq [2016,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 0, 2, 1, 3, 1, 1, 0, 0, 0, 0, 0, 0, 8]
      expect(sheet.row(2)).to eq ['Entry Summary Lines', 0, 20, 10, 30, 10, 10, 0, 0, 0, 0, 0, 0, 80]
      expect(sheet.row(3)).to eq ['Total Units', 0, 1086.4, 543.2, 1629.6, 543.2, 543.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4345.6]
      expect(sheet.row(4)).to eq ['Entry Type 01', 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet.row(5)).to eq ['Entry Type 02', 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 3]
      expect(sheet.row(6)).to eq ['Entry Type 13', 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
      expect(sheet.row(7)).to eq ['Total Entered Value', 0.0, 111.1, 55.55, 166.65, 55.55, 55.55, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 444.4]
      expect(sheet.row(8)).to eq ['Total Duty', 0.0, 88.88, 44.44, 133.32, 44.44, 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 355.52]
      expect(sheet.row(9)).to eq ['MPF', 0.0, 66.66, 33.33, 99.99, 33.33, 33.33, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 266.64]
      expect(sheet.row(10)).to eq ['HMF', 0.0, 44.44, 22.22, 66.66, 22.22, 22.22, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 177.76]
      expect(sheet.row(11)).to eq ['Cotton Fee', 0.0, 22.22, 11.11, 33.33, 11.11, 11.11, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet.row(12)).to eq ['Total Taxes', 0.0, 19.98, 9.99, 29.97, 9.99, 9.99, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 79.92]
      expect(sheet.row(13)).to eq ['Other Fees', 0, 17.76, 8.88, 26.64, 8.88, 8.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 71.04]
      expect(sheet.row(14)).to eq ['Total Fees', 0.0, 15.54, 7.77, 23.31, 7.77, 7.77, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 62.16]
      expect(sheet.row(15)).to eq ['Total Duty & Fees', 0.0, 104.42, 52.21, 156.63, 52.21, 52.21, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 417.68]
      expect(sheet.row(16)).to eq ['Total Broker Invoice', 0.0, 24.68, 12.34, 37.02, 12.34, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 98.72]
      expect(sheet.row(17)).to eq []
      expect(sheet.row(18)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(19)).to eq ['Number of Entries', 2, 0, 1, 1, 2, nil, nil, nil, nil, nil, nil, nil, 6]
      expect(sheet.row(20)).to eq ['Entry Summary Lines', 20, 0, 10, 10, 20, nil, nil, nil, nil, nil, nil, nil, 60]
      expect(sheet.row(21)).to eq ['Total Units', 1086.4, 0, 543.2, 543.2, 1086.4, nil, nil, nil, nil, nil, nil, nil, 3259.2]
      expect(sheet.row(22)).to eq ['Entry Type 01', 2, 0, 1, 1, 2, nil, nil, nil, nil, nil, nil, nil, 6]
      expect(sheet.row(23)).to eq ['Entry Type 02', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet.row(24)).to eq ['Entry Type 13', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet.row(25)).to eq ['Total Entered Value', 111.1, 0.0, 55.55, 55.55, 111.1, nil, nil, nil, nil, nil, nil, nil, 333.3]
      expect(sheet.row(26)).to eq ['Total Duty', 88.88, 0.0, 44.44, 44.44, 88.88, nil, nil, nil, nil, nil, nil, nil, 266.64]
      expect(sheet.row(27)).to eq ['MPF', 66.66, 0.0, 33.33, 33.33, 66.66, nil, nil, nil, nil, nil, nil, nil, 199.98]
      expect(sheet.row(28)).to eq ['HMF', 44.44, 0.0, 22.22, 22.22, 44.44, nil, nil, nil, nil, nil, nil, nil, 133.32]
      expect(sheet.row(29)).to eq ['Cotton Fee', 22.22, 0.0, 11.11, 11.11, 22.22, nil, nil, nil, nil, nil, nil, nil, 66.66]
      expect(sheet.row(30)).to eq ['Total Taxes', 19.98, 0.0, 9.99, 9.99, 19.98, nil, nil, nil, nil, nil, nil, nil, 59.94]
      expect(sheet.row(31)).to eq ['Other Fees', 17.76, 0, 8.88, 8.88, 17.76, nil, nil, nil, nil, nil, nil, nil, 53.28]
      expect(sheet.row(32)).to eq ['Total Fees', 15.54, 0.0, 7.77, 7.77, 15.54, nil, nil, nil, nil, nil, nil, nil, 46.62]
      expect(sheet.row(33)).to eq ['Total Duty & Fees', 104.42, 0.0, 52.21, 52.21, 104.42, nil, nil, nil, nil, nil, nil, nil, 313.26]
      expect(sheet.row(34)).to eq ['Total Broker Invoice', 24.68, 0.0, 12.34, 12.34, 24.68, nil, nil, nil, nil, nil, nil, nil, 74.04]
      expect(sheet.row(35)).to eq []
      expect(sheet.row(36)).to eq ['Variance 2016 / 2017','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(37)).to eq ['Number of Entries', 2, -2, 0, -2, 1, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(38)).to eq ['Entry Summary Lines', 20, -20, 0, -20, 10, nil, nil, nil, nil, nil, nil, nil, -10]
      expect(sheet.row(39)).to eq ['Total Units', 1086.4, -1086.4, 0, -1086.4, 543.2, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet.row(40)).to eq ['Entry Type 01', 2, -2, 1, -1, 2, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet.row(41)).to eq ['Entry Type 02', 0, 0, -1, -1, 0, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet.row(42)).to eq ['Entry Type 13', 0, 0, 0, 0, -1, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(43)).to eq ['Total Entered Value', 111.1, -111.1, 0.0, -111.1, 55.55, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet.row(44)).to eq ['Total Duty', 88.88, -88.88, 0.0, -88.88, 44.44, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet.row(45)).to eq ['MPF', 66.66, -66.66, 0.0, -66.66, 33.33, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet.row(46)).to eq ['HMF', 44.44, -44.44, 0.0, -44.44, 22.22, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet.row(47)).to eq ['Cotton Fee', 22.22, -22.22, 0.0, -22.22, 11.11, nil, nil, nil, nil, nil, nil, nil, -11.11]
      expect(sheet.row(48)).to eq ['Total Taxes', 19.98, -19.98, 0.0, -19.98, 9.99, nil, nil, nil, nil, nil, nil, nil, -9.99]
      expect(sheet.row(49)).to eq ['Other Fees', 17.76, -17.76, 0, -17.76, 8.88, nil, nil, nil, nil, nil, nil, nil, -8.88]
      expect(sheet.row(50)).to eq ['Total Fees', 15.54, -15.54, 0.0, -15.54, 7.77, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet.row(51)).to eq ['Total Duty & Fees', 104.42, -104.42, 0.0, -104.42, 52.21, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet.row(52)).to eq ['Total Broker Invoice', 24.68, -24.68, 0.0, -24.68, 12.34, nil, nil, nil, nil, nil, nil, nil, -12.34]

      raw_sheet = wb.worksheets[1]
      expect(raw_sheet.name).to eq "Data"
      expect(raw_sheet.rows.count).to eq 15
      expect(raw_sheet.row(0)).to eq ['Customer Number','Customer Name','Broker Reference','Entry Summary Line Count',
                                      'Entry Type','Total Entered Value','Total Duty','MPF','HMF','Cotton Fee',
                                      'Total Taxes','Total Fees','Other Taxes & Fees','Arrival Date','Release Date',
                                      'File Logged Date','Fiscal Date','ETA Date','Total Units','Total GST',
                                      'Country Export Codes','Mode of Transport','Total Broker Invoice']
      expect(raw_sheet.row(1)).to eq ['ABCD', 'Crudco', 'brok ref 1', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2016,2,16)), excel_date(Date.new(2018,2,3)), excel_date(Date.new(2018,3,4)), excel_date(Date.new(2018,4,5)), excel_date(Date.new(2018,5,6)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(2)).to eq ['ABCD', 'Crudco', 'brok ref 2', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2016,2,17)), excel_date(Date.new(2018,2,4)), excel_date(Date.new(2018,3,5)), excel_date(Date.new(2018,4,6)), excel_date(Date.new(2018,5,7)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(3)).to eq ['ABCD', 'Crudco', 'brok ref 3', 10, '02', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2016,3,3)), excel_date(Date.new(2018,2,5)), excel_date(Date.new(2018,3,6)), excel_date(Date.new(2018,4,7)), excel_date(Date.new(2018,5,8)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(4)).to eq ['ABCD', 'Crudco', 'brok ref 4', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2016,4,4)), excel_date(Date.new(2018,2,6)), excel_date(Date.new(2018,3,7)), excel_date(Date.new(2018,4,8)), excel_date(Date.new(2018,5,9)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(5)).to eq ['ABCD', 'Crudco', 'brok ref 5', 10, '02', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2016,4,16)), excel_date(Date.new(2018,2,7)), excel_date(Date.new(2018,3,8)), excel_date(Date.new(2018,4,9)), excel_date(Date.new(2018,5,10)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(6)).to eq ['ABCD', 'Crudco', 'brok ref 6', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2016,4,25)), excel_date(Date.new(2018,2,8)), excel_date(Date.new(2018,3,9)), excel_date(Date.new(2018,4,10)), excel_date(Date.new(2018,5,11)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(7)).to eq ['ABCD', 'Crudco', 'brok ref 7', 10, '13', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2016,5,15)), excel_date(Date.new(2018,2,9)), excel_date(Date.new(2018,3,10)), excel_date(Date.new(2018,4,11)), excel_date(Date.new(2018,5,12)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(8)).to eq ['ABCD', 'Crudco', 'brok ref 8', 10, '02', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2016,6,6)), excel_date(Date.new(2018,2,10)), excel_date(Date.new(2018,3,11)), excel_date(Date.new(2018,4,12)), excel_date(Date.new(2018,5,13)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(9)).to eq ['ABCD', 'Crudco', 'brok ref 9', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2017,1,1)), excel_date(Date.new(2018,2,11)), excel_date(Date.new(2018,3,12)), excel_date(Date.new(2018,4,13)), excel_date(Date.new(2018,5,14)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(10)).to eq ['ABCD', 'Crudco', 'brok ref 10', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2017,1,17)), excel_date(Date.new(2018,2,12)), excel_date(Date.new(2018,3,13)), excel_date(Date.new(2018,4,14)), excel_date(Date.new(2018,5,15)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(11)).to eq ['ABCD', 'Crudco', 'brok ref 11', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2017,3,2)), excel_date(Date.new(2018,2,13)), excel_date(Date.new(2018,3,14)), excel_date(Date.new(2018,4,15)), excel_date(Date.new(2018,5,16)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(12)).to eq ['ABCD', 'Crudco', 'brok ref 12', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2017,4,7)), excel_date(Date.new(2018,2,14)), excel_date(Date.new(2018,3,15)), excel_date(Date.new(2018,4,16)), excel_date(Date.new(2018,5,17)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(13)).to eq ['ABCD', 'Crudco', 'brok ref 13', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2017,5,21)), excel_date(Date.new(2018,2,15)), excel_date(Date.new(2018,3,16)), excel_date(Date.new(2018,4,17)), excel_date(Date.new(2018,5,18)), 543.2, 6.66, 'CN', 'S', 12.34]
      expect(raw_sheet.row(14)).to eq ['ABCD', 'Crudco', 'brok ref 14', 10, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, excel_date(Date.new(2017,5,22)), excel_date(Date.new(2018,2,16)), excel_date(Date.new(2018,3,17)), excel_date(Date.new(2018,4,18)), excel_date(Date.new(2018,5,19)), 543.2, 6.66, 'CN', 'S', 12.34]
    end

    def make_utc_date year, month, day
      ActiveSupport::TimeZone["UTC"].parse("#{year}-#{month}-#{day} 16:00")
    end

    def make_eastern_date year, month, day
      dt = make_utc_date(year, month, day)
      dt = dt.in_time_zone(ActiveSupport::TimeZone["America/New_York"])
      dt
    end

    it "generates spreadsheet based on ETA date" do
      ent_2016_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2016,1,16)
      ent_2016_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2016,1,17)
      ent_2017_Jan = make_entry 3, '01', :eta_date, make_utc_date(2017,1,17)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 4, '01', :eta_date, make_utc_date(2015,12,13)
      ent_2018_Feb = make_entry 5, '01', :eta_date, make_utc_date(2018,2,8)

      Timecop.freeze(make_eastern_date(2017,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_eta_date_[2016_2017].xls'

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 38
      expect(sheet.row(0)).to eq [2016,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(2)).to eq ['Entry Summary Lines', 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20]
      expect(sheet.row(3)).to eq ['Total Units', 1086.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1086.4]
      expect(sheet.row(4)).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(5)).to eq ['Total Entered Value', 111.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.1]
      expect(sheet.row(6)).to eq ['Total Duty', 88.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet.row(7)).to eq ['MPF', 66.66, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 66.66]
      expect(sheet.row(8)).to eq ['HMF', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet.row(9)).to eq ['Total Fees', 15.54, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 15.54]
      expect(sheet.row(10)).to eq ['Total Duty & Fees', 104.42, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 104.42]
      expect(sheet.row(11)).to eq ['Total Broker Invoice', 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet.row(12)).to eq []
      expect(sheet.row(13)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(14)).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(15)).to eq ['Entry Summary Lines', 10, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet.row(16)).to eq ['Total Units', 543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet.row(17)).to eq ['Entry Type 01', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(18)).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 55.55]
      expect(sheet.row(19)).to eq ['Total Duty', 44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 44.44]
      expect(sheet.row(20)).to eq ['MPF', 33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 33.33]
      expect(sheet.row(21)).to eq ['HMF', 22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 22.22]
      expect(sheet.row(22)).to eq ['Total Fees', 7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 7.77]
      expect(sheet.row(23)).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 52.21]
      expect(sheet.row(24)).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet.row(25)).to eq []
      expect(sheet.row(26)).to eq ['Variance 2016 / 2017','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(27)).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(28)).to eq ['Entry Summary Lines', -10, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -10]
      expect(sheet.row(29)).to eq ['Total Units', -543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet.row(30)).to eq ['Entry Type 01', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(31)).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet.row(32)).to eq ['Total Duty', -44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet.row(33)).to eq ['MPF', -33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet.row(34)).to eq ['HMF', -22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet.row(35)).to eq ['Total Fees', -7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet.row(36)).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet.row(37)).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]

      raw_sheet = wb.worksheets[1]
      expect(raw_sheet.rows.count).to eq 4
    end

    it "generates spreadsheet based on file logged date" do
      ent_2016_Jan_1 = make_entry 1, '01', :file_logged_date, make_utc_date(2016,1,16)
      ent_2016_Jan_2 = make_entry 2, '01', :file_logged_date, make_utc_date(2016,1,17)
      ent_2017_Jan = make_entry 3, '01', :file_logged_date, make_utc_date(2017,1,17)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 4, '01', :file_logged_date, make_utc_date(2015,12,13)
      ent_2018_Feb = make_entry 5, '01', :file_logged_date, make_utc_date(2018,2,8)

      Timecop.freeze(make_eastern_date(2017,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'file_logged_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => true, 'include_taxes' => false, 'include_other_fees' => false})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_file_logged_date_[2016_2017].xls'

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 41
      expect(sheet.row(0)).to eq [2016,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(2)).to eq ['Entry Summary Lines', 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20]
      expect(sheet.row(3)).to eq ['Total Units', 1086.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1086.4]
      expect(sheet.row(4)).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(5)).to eq ['Total Entered Value', 111.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.1]
      expect(sheet.row(6)).to eq ['Total Duty', 88.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet.row(7)).to eq ['MPF', 66.66, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 66.66]
      expect(sheet.row(8)).to eq ['HMF', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet.row(9)).to eq ['Cotton Fee', 22.22, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 22.22]
      expect(sheet.row(10)).to eq ['Total Fees', 15.54, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 15.54]
      expect(sheet.row(11)).to eq ['Total Duty & Fees', 104.42, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 104.42]
      expect(sheet.row(12)).to eq ['Total Broker Invoice', 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet.row(13)).to eq []
      expect(sheet.row(14)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(15)).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(16)).to eq ['Entry Summary Lines', 10, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet.row(17)).to eq ['Total Units', 543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet.row(18)).to eq ['Entry Type 01', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(19)).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 55.55]
      expect(sheet.row(20)).to eq ['Total Duty', 44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 44.44]
      expect(sheet.row(21)).to eq ['MPF', 33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 33.33]
      expect(sheet.row(22)).to eq ['HMF', 22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 22.22]
      expect(sheet.row(23)).to eq ['Cotton Fee', 11.11, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 11.11]
      expect(sheet.row(24)).to eq ['Total Fees', 7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 7.77]
      expect(sheet.row(25)).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 52.21]
      expect(sheet.row(26)).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet.row(27)).to eq []
      expect(sheet.row(28)).to eq ['Variance 2016 / 2017','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(29)).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(30)).to eq ['Entry Summary Lines', -10, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -10]
      expect(sheet.row(31)).to eq ['Total Units', -543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet.row(32)).to eq ['Entry Type 01', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(33)).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet.row(34)).to eq ['Total Duty', -44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet.row(35)).to eq ['MPF', -33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet.row(36)).to eq ['HMF', -22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet.row(37)).to eq ['Cotton Fee', -11.11, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -11.11]
      expect(sheet.row(38)).to eq ['Total Fees', -7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet.row(39)).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet.row(40)).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]

      raw_sheet = wb.worksheets[1]
      expect(raw_sheet.rows.count).to eq 4
    end

    it "generates spreadsheet based on fiscal date" do
      ent_2016_Jan_1 = make_entry 1, '01', :fiscal_date, make_utc_date(2016,1,16)
      ent_2016_Jan_2 = make_entry 2, '01', :fiscal_date, make_utc_date(2016,1,17)
      ent_2017_Jan = make_entry 3, '01', :fiscal_date, make_utc_date(2017,1,17)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 4, '01', :fiscal_date, make_utc_date(2015,12,13)
      ent_2018_Feb = make_entry 5, '01', :fiscal_date, make_utc_date(2018,2,8)

      Timecop.freeze(make_eastern_date(2017,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'fiscal_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => true, 'include_other_fees' => false})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_fiscal_date_[2016_2017].xls'

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 41
      expect(sheet.row(0)).to eq [2016,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(2)).to eq ['Entry Summary Lines', 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20]
      expect(sheet.row(3)).to eq ['Total Units', 1086.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1086.4]
      expect(sheet.row(4)).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(5)).to eq ['Total Entered Value', 111.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.1]
      expect(sheet.row(6)).to eq ['Total Duty', 88.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet.row(7)).to eq ['MPF', 66.66, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 66.66]
      expect(sheet.row(8)).to eq ['HMF', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet.row(9)).to eq ['Total Taxes', 19.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 19.98]
      expect(sheet.row(10)).to eq ['Total Fees', 15.54, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 15.54]
      expect(sheet.row(11)).to eq ['Total Duty & Fees', 104.42, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 104.42]
      expect(sheet.row(12)).to eq ['Total Broker Invoice', 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet.row(13)).to eq []
      expect(sheet.row(14)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(15)).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(16)).to eq ['Entry Summary Lines', 10, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet.row(17)).to eq ['Total Units', 543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet.row(18)).to eq ['Entry Type 01', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(19)).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 55.55]
      expect(sheet.row(20)).to eq ['Total Duty', 44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 44.44]
      expect(sheet.row(21)).to eq ['MPF', 33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 33.33]
      expect(sheet.row(22)).to eq ['HMF', 22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 22.22]
      expect(sheet.row(23)).to eq ['Total Taxes', 9.99, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 9.99]
      expect(sheet.row(24)).to eq ['Total Fees', 7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 7.77]
      expect(sheet.row(25)).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 52.21]
      expect(sheet.row(26)).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet.row(27)).to eq []
      expect(sheet.row(28)).to eq ['Variance 2016 / 2017','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(29)).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(30)).to eq ['Entry Summary Lines', -10, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -10]
      expect(sheet.row(31)).to eq ['Total Units', -543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet.row(32)).to eq ['Entry Type 01', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(33)).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet.row(34)).to eq ['Total Duty', -44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet.row(35)).to eq ['MPF', -33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet.row(36)).to eq ['HMF', -22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet.row(37)).to eq ['Total Taxes', -9.99, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -9.99]
      expect(sheet.row(38)).to eq ['Total Fees', -7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet.row(39)).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet.row(40)).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]

      raw_sheet = wb.worksheets[1]
      expect(raw_sheet.rows.count).to eq 4
    end

    it "generates spreadsheet based on release date" do
      ent_2016_Jan_1 = make_entry 1, '01', :release_date, make_utc_date(2016,1,16)
      ent_2016_Jan_2 = make_entry 2, '01', :release_date, make_utc_date(2016,1,17)
      ent_2017_Jan = make_entry 3, '01', :release_date, make_utc_date(2017,1,17)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 4, '01', :release_date, make_utc_date(2015,12,13)
      ent_2018_Feb = make_entry 5, '01', :release_date, make_utc_date(2018,2,8)

      Timecop.freeze(make_eastern_date(2017,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'release_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => true})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_release_date_[2016_2017].xls'

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 41
      expect(sheet.row(0)).to eq [2016,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(2)).to eq ['Entry Summary Lines', 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20]
      expect(sheet.row(3)).to eq ['Total Units', 1086.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1086.4]
      expect(sheet.row(4)).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(5)).to eq ['Total Entered Value', 111.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.1]
      expect(sheet.row(6)).to eq ['Total Duty', 88.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet.row(7)).to eq ['MPF', 66.66, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 66.66]
      expect(sheet.row(8)).to eq ['HMF', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet.row(9)).to eq ['Other Fees', 17.76, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 17.76]
      expect(sheet.row(10)).to eq ['Total Fees', 15.54, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 15.54]
      expect(sheet.row(11)).to eq ['Total Duty & Fees', 104.42, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 104.42]
      expect(sheet.row(12)).to eq ['Total Broker Invoice', 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet.row(13)).to eq []
      expect(sheet.row(14)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(15)).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(16)).to eq ['Entry Summary Lines', 10, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet.row(17)).to eq ['Total Units', 543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet.row(18)).to eq ['Entry Type 01', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(19)).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 55.55]
      expect(sheet.row(20)).to eq ['Total Duty', 44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 44.44]
      expect(sheet.row(21)).to eq ['MPF', 33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 33.33]
      expect(sheet.row(22)).to eq ['HMF', 22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 22.22]
      expect(sheet.row(23)).to eq ['Other Fees', 8.88, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 8.88]
      expect(sheet.row(24)).to eq ['Total Fees', 7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 7.77]
      expect(sheet.row(25)).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 52.21]
      expect(sheet.row(26)).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet.row(27)).to eq []
      expect(sheet.row(28)).to eq ['Variance 2016 / 2017','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(29)).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(30)).to eq ['Entry Summary Lines', -10, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -10]
      expect(sheet.row(31)).to eq ['Total Units', -543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet.row(32)).to eq ['Entry Type 01', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(33)).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet.row(34)).to eq ['Total Duty', -44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet.row(35)).to eq ['MPF', -33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet.row(36)).to eq ['HMF', -22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet.row(37)).to eq ['Other Fees', -8.88, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -8.88]
      expect(sheet.row(38)).to eq ['Total Fees', -7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet.row(39)).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet.row(40)).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]

      raw_sheet = wb.worksheets[1]
      expect(raw_sheet.rows.count).to eq 4
    end

    it "ensures years are in chronological order" do
      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017,1,16)
      ent_2017_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2017,1,17)
      ent_2018_Jan = make_entry 3, '01', :eta_date, make_utc_date(2018,1,17)

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        # Report should wind up being ordered 2017 then 2018, not 2018 then 2017.
        @temp = described_class.run_report(u, {'year_1' => '2018', 'year_2' => '2017', 'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 38
      expect(sheet.row(0)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(13)).to eq [2018,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(14)).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(26)).to eq ['Variance 2017 / 2018','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(27)).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "defaults years when not provided" do
      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017,1,16)
      ent_2017_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2017,1,17)
      ent_2018_Jan = make_entry 3, '01', :eta_date, make_utc_date(2018,1,17)

      # These should be excluded because they are outside our date ranges.
      ent_2016_Dec = make_entry 3, '01', :eta_date, make_utc_date(2016,12,13)
      ent_2019_Feb = make_entry 4, '01', :eta_date, make_utc_date(2019,2,8)

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 38
      expect(sheet.row(0)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(13)).to eq [2018,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(14)).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(26)).to eq ['Variance 2017 / 2018','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(27)).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "appropriate handles null number values" do
      ent_2016_Jan_1 = Factory(:entry, customer_number:'ABCD', customer_name:'Crudco', broker_reference:"brok ref 1",
                      entry_type:'01', arrival_date:make_utc_date(2016,1,16), importer_id:importer.id)
      ent_2016_Jan_2 = make_entry 2, '01', :arrival_date, make_utc_date(2016,1,17)
      ent_2017_Jan = Factory(:entry, customer_number:'ABCD', customer_name:'Crudco', broker_reference:"brok ref 3",
                      entry_type:'01', arrival_date:make_utc_date(2017,1,1), importer_id:importer.id)

      Timecop.freeze(make_eastern_date(2017,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'arrival_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => true, 'include_taxes' => true, 'include_other_fees' => true})
      end

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 47
      expect(sheet.row(0)).to eq [2016,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(2)).to eq ['Entry Summary Lines', 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10]
      expect(sheet.row(3)).to eq ['Total Units', 543.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 543.2]
      expect(sheet.row(4)).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(5)).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 55.55]
      expect(sheet.row(6)).to eq ['Total Duty', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet.row(7)).to eq ['MPF', 33.33, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 33.33]
      expect(sheet.row(8)).to eq ['HMF', 22.22, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 22.22]
      expect(sheet.row(9)).to eq ['Cotton Fee', 11.11, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 11.11]
      expect(sheet.row(10)).to eq ['Total Taxes', 9.99, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 9.99]
      expect(sheet.row(11)).to eq ['Other Fees', 8.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 8.88]
      expect(sheet.row(12)).to eq ['Total Fees', 7.77, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.77]
      expect(sheet.row(13)).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 52.21]
      expect(sheet.row(14)).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 12.34]
      expect(sheet.row(15)).to eq []
      expect(sheet.row(16)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(17)).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(18)).to eq ['Entry Summary Lines', 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet.row(19)).to eq ['Total Units', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(20)).to eq ['Entry Type 01', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(21)).to eq ['Total Entered Value', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(22)).to eq ['Total Duty', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(23)).to eq ['MPF', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(24)).to eq ['HMF', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(25)).to eq ['Cotton Fee', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(26)).to eq ['Total Taxes', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(27)).to eq ['Other Fees', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(28)).to eq ['Total Fees', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(29)).to eq ['Total Duty & Fees', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(30)).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(31)).to eq []
      expect(sheet.row(32)).to eq ['Variance 2016 / 2017','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(33)).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(34)).to eq ['Entry Summary Lines', -10, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -10]
      expect(sheet.row(35)).to eq ['Total Units', -543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet.row(36)).to eq ['Entry Type 01', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(37)).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet.row(38)).to eq ['Total Duty', -44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet.row(39)).to eq ['MPF', -33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet.row(40)).to eq ['HMF', -22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet.row(41)).to eq ['Cotton Fee', -11.11, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -11.11]
      expect(sheet.row(42)).to eq ['Total Taxes', -9.99, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -9.99]
      expect(sheet.row(43)).to eq ['Other Fees', -8.88, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -8.88]
      expect(sheet.row(44)).to eq ['Total Fees', -7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet.row(45)).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet.row(46)).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]
    end

    it "filters by transport mode when provided" do
      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017,1,16)
      ent_2017_Jan_1.update_attributes :transport_mode_code => 10
      ent_2017_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2017,1,17)
      ent_2017_Jan_2.update_attributes :transport_mode_code => 41

      # This is a rail shipment, and we're looking for air and sea only, so it should be excluded.
      ent_2018_Jan = make_entry 3, '01', :eta_date, make_utc_date(2018,1,17)
      ent_2018_Jan.update_attributes :transport_mode_code => 20

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false, 'mode_of_transport' => ['Air','Sea']})
      end

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 38
      expect(sheet.row(0)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(13)).to eq [2018,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(14)).to eq ['Number of Entries', 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet.row(26)).to eq ['Variance 2017 / 2018','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(27)).to eq ['Number of Entries', -2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -2]
    end

    it "handles multiple importer selection" do
      importer_2 = Factory(:company, name:'Crudco Bitter Rival')

      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017,1,16)
      ent_2017_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2017,1,17)
      ent_2017_Jan_2.update_attributes :importer_id => importer_2.id
      ent_2018_Jan = make_entry 3, '01', :eta_date, make_utc_date(2018,1,17)
      ent_2018_Jan.update_attributes :importer_id => importer_2.id

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'eta_date', 'importer_ids' => [importer.id, importer_2.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 2

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 38
      expect(sheet.row(0)).to eq [2017,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(1)).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(13)).to eq [2018,'January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(14)).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(26)).to eq ['Variance 2017 / 2018','January','February','March','April','May','June','July','August','September','October','November','December','Grand Totals']
      expect(sheet.row(27)).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "handles UTC time value that falls into another month when converted to eastern, release" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry 1, '01', :release_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00")

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'release_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]
      expect(sheet.row(1)).to eq ['Number of Entries', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "handles UTC time value that falls off the report when converted to eastern, release" do
      # This should be interpreted as December 2016, and left off the report, not January 2017.
      ent_2016 = make_entry 1, '01', :release_date, ActiveSupport::TimeZone["UTC"].parse("2017-01-01 02:00")

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'release_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]
      expect(sheet.row(1)).to eq ['Number of Entries', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    end

    it "handles UTC time value that falls into another month when converted to eastern, arrival" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry 1, '01', :arrival_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00")

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'arrival_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]
      expect(sheet.row(1)).to eq ['Number of Entries', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "handles UTC time value that falls into another month when converted to eastern, file logged" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry 1, '01', :file_logged_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00")

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'file_logged_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]
      expect(sheet.row(1)).to eq ['Number of Entries', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end
  end

end