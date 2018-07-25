describe OpenChain::Report::CompanyYearOverYearReport do

  describe "permission?" do
    let(:ms) { stub_master_setup }
    let (:u) { Factory(:user) }
    let (:group) { Group.use_system_group 'company_yoy_report', create: true }

    it "allows access for users who can view entries, are subscribed to YoY report custom feature and are in YoY group" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("Company Year Over Year Report").and_return true
      expect(u).to receive(:in_group?).with(group).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "prevents access by users who cannot view entries" do
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who are not subscribed to YoY report custom feature" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("Company Year Over Year Report").and_return false
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who are not in the YoY group" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("Company Year Over Year Report").and_return true
      expect(u).to receive(:in_group?).with(group).and_return false
      expect(described_class.permission? u).to eq false
    end
  end

  describe "run_report" do
    let (:u) { Factory(:user) }
    let(:importer) { Factory(:company, name:'Crudco Consumables and Poisons, Inc.', system_code:'CRUDCO') }

    after { @temp.close if @temp }

    def make_entry division, date_range_field, date_range_field_val, customer_number:'ANYCUST', invoice_line_count:2
      entry = Factory(:entry, importer_id:importer.id, division_number:division, summary_line_count:10,
                      broker_invoice_total:12.34, customer_number:customer_number)
      entry.update_attributes date_range_field => date_range_field_val
      inv = entry.commercial_invoices.create! invoice_number:"inv-#{entry.id}"
      for i in 1..invoice_line_count
        inv.commercial_invoice_lines.create!
      end
      entry
    end

    it "generates spreadsheet" do
      xref_div_1 = DataCrossReference.create! key:'0001', value:'Division A', cross_reference_type: DataCrossReference::VFI_DIVISION
      xref_div_2 = DataCrossReference.create! key:'0002', value:'Division B', cross_reference_type: DataCrossReference::VFI_DIVISION
      xref_div_2 = DataCrossReference.create! key:'0013', value:'Division C', cross_reference_type: DataCrossReference::VFI_DIVISION

      ent_2016_Feb_1 = make_entry '0001', :release_date, make_utc_date(2016,2,16), invoice_line_count:3
      ent_2016_Feb_2 = make_entry '0001', :release_date, make_utc_date(2016,2,17), invoice_line_count:5
      ent_2016_Mar = make_entry '0002', :release_date, make_utc_date(2016,3,3)
      ent_2016_Apr_1 = make_entry '0001', :release_date, make_utc_date(2016,4,4)
      ent_2016_Apr_2 = make_entry '0002', :release_date, make_utc_date(2016,4,16)
      ent_2016_Apr_3 = make_entry '0001', :release_date, make_utc_date(2016,4,25)
      ent_2016_May = make_entry '0013', :release_date, make_utc_date(2016,5,15)
      # This one is excluded from YTD because it's after the current month, and the report involves the current year.
      ent_2016_Jun = make_entry '0002', :release_date, make_utc_date(2016,6,6)

      ent_2017_Jan_1 = make_entry '0001', :release_date, make_utc_date(2017,1,1)
      ent_2017_Jan_2 = make_entry '0001', :release_date, make_utc_date(2017,1,17)
      ent_2017_Mar = make_entry '0001', :release_date, make_utc_date(2017,3,2)
      ent_2017_Apr = make_entry '0001', :release_date, make_utc_date(2017,4,7)
      ent_2017_May_1 = make_entry '0001', :release_date, make_utc_date(2017,5,21)
      ent_2017_May_2 = make_entry '0001', :release_date, make_utc_date(2017,5,22)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry '0001', :release_date, make_utc_date(2015,12,13)
      ent_2018_Feb = make_entry '0001', :release_date, make_utc_date(2018,2,8)

      # All importers are included on this report.
      ent_2016_Feb_different_importer = make_entry '0001', :release_date, make_utc_date(2016,2,11)
      importer_2 = Factory(:company, name:'Crudco Bitter Rival')
      ent_2016_Feb_different_importer.update_attributes :importer_id => importer_2.id

      # Eddie Bauer FTZ entries don't have release set.  They work off arrival date.  Beyond that, they're
      # treated the same as all other entries on this report in terms of how they are broken down by month/year.
      eddie_ent_2016_May = make_entry '0002', :arrival_date, make_utc_date(2016,5,13), customer_number:'EDDIEFTZ'
      eddie_ent_2017_Apr = make_entry '0002', :arrival_date, make_utc_date(2017,4,11), customer_number:'EDDIEFTZ'

      Timecop.freeze(make_eastern_date(2017,6,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017'})
      end
      expect(@temp.original_filename).to eq 'Company_YoY_[2016_2017].xls'

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 3

      sheet_a = wb.worksheets[0]
      expect(sheet_a.name).to eq "0001 - Division A"
      expect(sheet_a.rows.count).to eq 17
      expect(sheet_a.row(0)).to eq [2016,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_a.row(1)).to eq ['Entries Transmitted', 0, 3, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 5]
      expect(sheet_a.row(2)).to eq ['Entry Summary Lines', 0, 10, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 14]
      expect(sheet_a.row(3)).to eq ['ABI Lines', 0, 30, 0, 20, 0, 0, 0, 0, 0, 0, 0, 0, 50]
      expect(sheet_a.row(4)).to eq ['Total Broker Invoice', 0.0, 37.02, 0.0, 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 61.70]
      expect(sheet_a.row(5)).to eq []
      expect(sheet_a.row(6)).to eq [2017,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_a.row(7)).to eq ['Entries Transmitted', 2, 0, 1, 1, 2, nil, nil, nil, nil, nil, nil, nil, 6]
      expect(sheet_a.row(8)).to eq ['Entry Summary Lines', 4, 0, 2, 2, 4, nil, nil, nil, nil, nil, nil, nil, 12]
      expect(sheet_a.row(9)).to eq ['ABI Lines', 20, 0, 10, 10, 20, nil, nil, nil, nil, nil, nil, nil, 60]
      expect(sheet_a.row(10)).to eq ['Total Broker Invoice', 24.68, 0.0, 12.34, 12.34, 24.68, nil, nil, nil, nil, nil, nil, nil, 74.04]
      expect(sheet_a.row(11)).to eq []
      expect(sheet_a.row(12)).to eq ['Variance','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_a.row(13)).to eq ['Entries Transmitted', 2, -3, 1, -1, 2, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet_a.row(14)).to eq ['Entry Summary Lines', 4, -10, 2, -2, 4, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet_a.row(15)).to eq ['ABI Lines', 20, -30, 10, -10, 20, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet_a.row(16)).to eq ['Total Broker Invoice', 24.68, -37.02, 12.34, -12.34, 24.68, nil, nil, nil, nil, nil, nil, nil, 12.34]

      sheet_b = wb.worksheets[1]
      expect(sheet_b.name).to eq "0002 - Division B"
      expect(sheet_b.rows.count).to eq 17
      expect(sheet_b.row(0)).to eq [2016,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_b.row(1)).to eq ['Entries Transmitted', 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 3]
      expect(sheet_b.row(2)).to eq ['Entry Summary Lines', 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 6]
      expect(sheet_b.row(3)).to eq ['ABI Lines', 0, 0, 10, 10, 10, 10, 0, 0, 0, 0, 0, 0, 30]
      expect(sheet_b.row(4)).to eq ['Total Broker Invoice', 0.0, 0.0, 12.34, 12.34, 12.34, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 37.02]
      expect(sheet_b.row(5)).to eq []
      expect(sheet_b.row(6)).to eq [2017,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_b.row(7)).to eq ['Entries Transmitted', 0, 0, 0, 1, 0, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet_b.row(8)).to eq ['Entry Summary Lines', 0, 0, 0, 2, 0, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet_b.row(9)).to eq ['ABI Lines', 0, 0, 0, 10, 0, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet_b.row(10)).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 12.34, 0.0, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet_b.row(11)).to eq []
      expect(sheet_b.row(12)).to eq ['Variance','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_b.row(13)).to eq ['Entries Transmitted', 0, 0, -1, 0, -1, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet_b.row(14)).to eq ['Entry Summary Lines', 0, 0, -2, 0, -2, nil, nil, nil, nil, nil, nil, nil, -4]
      expect(sheet_b.row(15)).to eq ['ABI Lines', 0, 0, -10, 0, -10, nil, nil, nil, nil, nil, nil, nil, -20]
      expect(sheet_b.row(16)).to eq ['Total Broker Invoice', 0, 0, -12.34, 0, -12.34, nil, nil, nil, nil, nil, nil, nil, -24.68]

      sheet_c = wb.worksheets[2]
      expect(sheet_c.name).to eq "0013 - Division C"
      expect(sheet_c.rows.count).to eq 17
      expect(sheet_c.row(0)).to eq [2016,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_c.row(1)).to eq ['Entries Transmitted', 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
      expect(sheet_c.row(2)).to eq ['Entry Summary Lines', 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet_c.row(3)).to eq ['ABI Lines', 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 10]
      expect(sheet_c.row(4)).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 12.34]
      expect(sheet_c.row(5)).to eq []
      expect(sheet_c.row(6)).to eq [2017,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_c.row(7)).to eq ['Entries Transmitted', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_c.row(8)).to eq ['Entry Summary Lines', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_c.row(9)).to eq ['ABI Lines', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_c.row(10)).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet_c.row(11)).to eq []
      expect(sheet_c.row(12)).to eq ['Variance','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_c.row(13)).to eq ['Entries Transmitted', 0, 0, 0, 0, -1, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet_c.row(14)).to eq ['Entry Summary Lines', 0, 0, 0, 0, -2, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet_c.row(15)).to eq ['ABI Lines', 0, 0, 0, 0, -10, nil, nil, nil, nil, nil, nil, nil, -10]
      expect(sheet_c.row(16)).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, -12.34, nil, nil, nil, nil, nil, nil, nil, -12.34]
    end

    def make_utc_date year, month, day
      ActiveSupport::TimeZone["UTC"].parse("#{year}-#{month}-#{day} 16:00")
    end

    def make_eastern_date year, month, day
      dt = make_utc_date(year, month, day)
      dt = dt.in_time_zone(ActiveSupport::TimeZone["America/New_York"])
      dt
    end

    it "generates spreadsheet using two years that are not current year" do
      ent_2016_Apr = make_entry '0001', :release_date, make_utc_date(2016,4,4)
      ent_2016_Jun = make_entry '0001', :release_date, make_utc_date(2016,6,6)

      ent_2017_Mar = make_entry '0001', :release_date, make_utc_date(2017,3,2)
      ent_2017_Apr = make_entry '0001', :release_date, make_utc_date(2017,4,7)
      ent_2017_Jul = make_entry '0001', :release_date, make_utc_date(2017,7,22)

      Timecop.freeze(make_eastern_date(2018,6,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017'})
      end
      expect(@temp.original_filename).to eq 'Company_YoY_[2016_2017].xls'

      wb = Spreadsheet.open @temp.path

      sheet_a = wb.worksheets[0]
      expect(sheet_a.rows.count).to eq 17
      expect(sheet_a.row(0)).to eq [2016,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_a.row(1)).to eq ['Entries Transmitted', 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet_a.row(2)).to eq ['Entry Summary Lines', 0, 0, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet_a.row(3)).to eq ['ABI Lines', 0, 0, 0, 10, 0, 10, 0, 0, 0, 0, 0, 0, 20]
      expect(sheet_a.row(4)).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 12.34, 0.0, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet_a.row(5)).to eq []
      expect(sheet_a.row(6)).to eq [2017,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_a.row(7)).to eq ['Entries Transmitted', 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 3]
      expect(sheet_a.row(8)).to eq ['Entry Summary Lines', 0, 0, 2, 2, 0, 0, 2, 0, 0, 0, 0, 0, 6]
      expect(sheet_a.row(9)).to eq ['ABI Lines', 0, 0, 10, 10, 0, 0, 10, 0, 0, 0, 0, 0, 30]
      expect(sheet_a.row(10)).to eq ['Total Broker Invoice', 0.0, 0.0, 12.34, 12.34, 0.0, 0.0, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 37.02]
      expect(sheet_a.row(11)).to eq []
      expect(sheet_a.row(12)).to eq ['Variance','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet_a.row(13)).to eq ['Entries Transmitted', 0, 0, 1, 0, 0, -1, 1, 0, 0, 0, 0, 0, 1]
      expect(sheet_a.row(14)).to eq ['Entry Summary Lines', 0, 0, 2, 0, 0, -2, 2, 0, 0, 0, 0, 0, 2]
      expect(sheet_a.row(15)).to eq ['ABI Lines', 0, 0, 10, 0, 0, -10, 10, 0, 0, 0, 0, 0, 10]
      expect(sheet_a.row(16)).to eq ['Total Broker Invoice', 0.0, 0.0, 12.34, 0.0, 0.0, -12.34, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 12.34]
    end

    it "ensures years are in chronological order" do
      ent_2017_Jan_1 = make_entry '0001', :release_date, make_utc_date(2017,1,16)
      ent_2017_Jan_2 = make_entry '0001', :release_date, make_utc_date(2017,1,17)
      ent_2018_Jan = make_entry '0001', :release_date, make_utc_date(2018,1,17)

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        # Report should wind up being ordered 2017 then 2018, not 2018 then 2017.
        @temp = described_class.run_report(u, {'year_1' => '2018', 'year_2' => '2017'})
      end

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 1

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 17
      expect(sheet.row(0)).to eq [2017,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(1)).to eq ['Entries Transmitted', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(6)).to eq [2018,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(7)).to eq ['Entries Transmitted', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(12)).to eq ['Variance','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(13)).to eq ['Entries Transmitted', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "defaults years when not provided" do
      ent_2017_Jan_1 = make_entry '0001', :release_date, make_utc_date(2017,1,16)
      ent_2017_Jan_2 = make_entry '0001', :release_date, make_utc_date(2017,1,17)
      ent_2018_Jan = make_entry '0001', :release_date, make_utc_date(2018,1,17)

      # These should be excluded because they are outside our date ranges.
      ent_2016_Dec = make_entry '0001', :release_date, make_utc_date(2016,12,13)
      ent_2019_Feb = make_entry '0001', :release_date, make_utc_date(2019,2,8)

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {})
      end

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 1

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 17
      expect(sheet.row(0)).to eq [2017,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(1)).to eq ['Entries Transmitted', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(6)).to eq [2018,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(7)).to eq ['Entries Transmitted', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(12)).to eq ['Variance','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(13)).to eq ['Entries Transmitted', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "appropriate handles null number values" do
      ent_2016_Jan_1 = Factory(:entry, importer_id:importer.id, division_number:'0001', customer_number:'ANYCUST', release_date:make_utc_date(2016,1,16), summary_line_count:7)
      ent_2016_Jan_2 = make_entry '0001', :release_date, make_utc_date(2016,1,17)
      ent_2017_Jan = Factory(:entry, importer_id:importer.id, division_number:'0001', customer_number:'ANYCUST', release_date:make_utc_date(2017,1,1), summary_line_count:8)

      Timecop.freeze(make_eastern_date(2017,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017'})
      end

      wb = Spreadsheet.open @temp.path
      expect(wb.worksheets.length).to eq 1

      sheet = wb.worksheets[0]
      expect(sheet.rows.count).to eq 17
      expect(sheet.row(0)).to eq [2016,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(1)).to eq ['Entries Transmitted', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet.row(2)).to eq ['Entry Summary Lines', 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3]
      expect(sheet.row(3)).to eq ['ABI Lines', 17, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17]
      expect(sheet.row(4)).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 12.34]
      expect(sheet.row(5)).to eq []
      expect(sheet.row(6)).to eq [2017,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(7)).to eq ['Entries Transmitted', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(8)).to eq ['Entry Summary Lines', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet.row(9)).to eq ['ABI Lines', 8, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 8]
      expect(sheet.row(10)).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet.row(11)).to eq []
      expect(sheet.row(12)).to eq ['Variance','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(13)).to eq ['Entries Transmitted', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet.row(14)).to eq ['Entry Summary Lines', -2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet.row(15)).to eq ['ABI Lines', -9, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -9]
      expect(sheet.row(16)).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]
    end

    it "handles UTC time value that falls into another month when converted to eastern" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry '0001', :release_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00")

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018'})
      end

      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]
      expect(sheet.row(1)).to eq ['Entries Transmitted', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "handles UTC time value that falls off the report when converted to eastern" do
      # This should be interpreted as December 2016, and left off the report, not January 2017.
      ent_2016 = make_entry '0001', :release_date, ActiveSupport::TimeZone["UTC"].parse("2017-01-01 02:00")

      # Need to include an entry that is on the report otherwise no report will be generated.
      ent_2017_Feb = make_entry '0001', :release_date, make_utc_date(2017,2,2)

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018'})
      end

      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]
      expect(sheet.row(0)).to eq [2017,'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Grand Total (YTD)']
      expect(sheet.row(1)).to eq ['Entries Transmitted', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "handles UTC time value that falls into another month when converted to eastern, arrival" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry '0001', :arrival_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00"), customer_number:'EDDIEFTZ'

      Timecop.freeze(make_eastern_date(2018,5,28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018'})
      end

      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]
      expect(sheet.row(1)).to eq ['Entries Transmitted', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end
  end

end