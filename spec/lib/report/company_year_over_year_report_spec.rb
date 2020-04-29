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
    let!(:xref_div_1) { DataCrossReference.create key:'0001', value:'Division A', cross_reference_type: DataCrossReference::VFI_DIVISION }

    after { @temp.close if @temp }

    def make_entry division, date_range_field, date_range_field_val, customer_number:'ANYCUST', invoice_line_count:2, entry_number:'123doesntmatter'
      entry = Factory(:entry, importer_id:importer.id, division_number:division, summary_line_count:10,
                      broker_invoice_total:12.34, customer_number:customer_number, entry_number:entry_number)
      entry.update_attributes date_range_field => date_range_field_val
      inv = entry.commercial_invoices.create! invoice_number:"inv-#{entry.id}"
      for i in 1..invoice_line_count
        inv.commercial_invoice_lines.create!
      end
      entry
    end

    it "generates spreadsheet" do
      xref_div_2 = DataCrossReference.create! key:'0002', value:'Division B', cross_reference_type: DataCrossReference::VFI_DIVISION
      xref_div_2 = DataCrossReference.create! key:'0013', value:'Division C', cross_reference_type: DataCrossReference::VFI_DIVISION

      ent_2016_Feb_1 = make_entry '0001', :release_date, make_utc_date(2016, 2, 16), invoice_line_count:3
      ent_2016_Feb_2 = make_entry '0001', :release_date, make_utc_date(2016, 2, 17), invoice_line_count:5
      ent_2016_Mar = make_entry '0002', :release_date, make_utc_date(2016, 3, 3)
      ent_2016_Apr_1 = make_entry '0001', :release_date, make_utc_date(2016, 4, 4)
      ent_2016_Apr_2 = make_entry '0002', :release_date, make_utc_date(2016, 4, 16)
      ent_2016_Apr_3 = make_entry '0001', :release_date, make_utc_date(2016, 4, 25)
      ent_2016_May = make_entry '0013', :release_date, make_utc_date(2016, 5, 15)
      # This one is excluded from YTD because it's after the current month, and the report involves the current year.
      ent_2016_Jun = make_entry '0002', :release_date, make_utc_date(2016, 6, 6)

      ent_2017_Jan_1 = make_entry '0001', :release_date, make_utc_date(2017, 1, 1)
      ent_2017_Jan_2 = make_entry '0001', :release_date, make_utc_date(2017, 1, 17)
      ent_2017_Mar = make_entry '0001', :release_date, make_utc_date(2017, 3, 2)
      ent_2017_Apr = make_entry '0001', :release_date, make_utc_date(2017, 4, 7)
      ent_2017_May_1 = make_entry '0001', :release_date, make_utc_date(2017, 5, 21)
      ent_2017_May_2 = make_entry '0001', :release_date, make_utc_date(2017, 5, 22)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry '0001', :release_date, make_utc_date(2015, 12, 13)
      ent_2018_Feb = make_entry '0001', :release_date, make_utc_date(2018, 2, 8)

      # All importers are included on this report.
      ent_2016_Feb_different_importer = make_entry '0001', :release_date, make_utc_date(2016, 2, 11)
      importer_2 = Factory(:company, name:'Crudco Bitter Rival')
      ent_2016_Feb_different_importer.update_attributes :importer_id => importer_2.id

      # Eddie Bauer FTZ entries don't have release set.  They work off arrival date.  Beyond that, they're
      # treated the same as all other entries on this report in terms of how they are broken down by month/year.
      eddie_ent_2016_May = make_entry '0002', :arrival_date, make_utc_date(2016, 5, 13), customer_number:'EDDIEFTZ'
      eddie_ent_2017_Apr = make_entry '0002', :arrival_date, make_utc_date(2017, 4, 11), customer_number:'EDDIEFTZ'

      # Toronto entries don't have a division number set.  Division is determined based on entry number prefix.
      toronto_ent_2016_May = make_entry nil, :release_date, make_utc_date(2016, 5, 13), entry_number:'1198555222'
      toronto_ent_2017_Apr = make_entry nil, :release_date, make_utc_date(2017, 4, 11), entry_number:'1198555223'

      Timecop.freeze(make_eastern_date(2017, 6, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017'})
      end
      expect(@temp.original_filename).to eq 'Company_YoY_[2016_2017].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 4

      sheet_a = reader["0001 - Division A"]
      expect(sheet_a).to_not be_nil
      expect(sheet_a.length).to eq 17
      expect(sheet_a[0]).to eq [2016, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_a[1]).to eq ['Entries Transmitted', 0, 3, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 5]
      expect(sheet_a[2]).to eq ['Entry Summary Lines', 0, 10, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 14]
      expect(sheet_a[3]).to eq ['ABI Lines', 0, 30, 0, 20, 0, 0, 0, 0, 0, 0, 0, 0, 50]
      expect(sheet_a[4]).to eq ['Total Broker Invoice', 0.0, 37.02, 0.0, 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 61.70]
      expect(sheet_a[5]).to eq []
      expect(sheet_a[6]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_a[7]).to eq ['Entries Transmitted', 2, 0, 1, 1, 2, nil, nil, nil, nil, nil, nil, nil, 6]
      expect(sheet_a[8]).to eq ['Entry Summary Lines', 4, 0, 2, 2, 4, nil, nil, nil, nil, nil, nil, nil, 12]
      expect(sheet_a[9]).to eq ['ABI Lines', 20, 0, 10, 10, 20, nil, nil, nil, nil, nil, nil, nil, 60]
      expect(sheet_a[10]).to eq ['Total Broker Invoice', 24.68, 0.0, 12.34, 12.34, 24.68, nil, nil, nil, nil, nil, nil, nil, 74.04]
      expect(sheet_a[11]).to eq []
      expect(sheet_a[12]).to eq ['Variance', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_a[13]).to eq ['Entries Transmitted', 2, -3, 1, -1, 2, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet_a[14]).to eq ['Entry Summary Lines', 4, -10, 2, -2, 4, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet_a[15]).to eq ['ABI Lines', 20, -30, 10, -10, 20, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet_a[16]).to eq ['Total Broker Invoice', 24.68, -37.02, 12.34, -12.34, 24.68, nil, nil, nil, nil, nil, nil, nil, 12.34]

      sheet_b = reader["0002 - Division B"]
      expect(sheet_b).to_not be_nil
      expect(sheet_b.length).to eq 17
      expect(sheet_b[0]).to eq [2016, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_b[1]).to eq ['Entries Transmitted', 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 3]
      expect(sheet_b[2]).to eq ['Entry Summary Lines', 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 6]
      expect(sheet_b[3]).to eq ['ABI Lines', 0, 0, 10, 10, 10, 10, 0, 0, 0, 0, 0, 0, 30]
      expect(sheet_b[4]).to eq ['Total Broker Invoice', 0.0, 0.0, 12.34, 12.34, 12.34, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 37.02]
      expect(sheet_b[5]).to eq []
      expect(sheet_b[6]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_b[7]).to eq ['Entries Transmitted', 0, 0, 0, 1, 0, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet_b[8]).to eq ['Entry Summary Lines', 0, 0, 0, 2, 0, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet_b[9]).to eq ['ABI Lines', 0, 0, 0, 10, 0, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet_b[10]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 12.34, 0.0, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet_b[11]).to eq []
      expect(sheet_b[12]).to eq ['Variance', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_b[13]).to eq ['Entries Transmitted', 0, 0, -1, 0, -1, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet_b[14]).to eq ['Entry Summary Lines', 0, 0, -2, 0, -2, nil, nil, nil, nil, nil, nil, nil, -4]
      expect(sheet_b[15]).to eq ['ABI Lines', 0, 0, -10, 0, -10, nil, nil, nil, nil, nil, nil, nil, -20]
      expect(sheet_b[16]).to eq ['Total Broker Invoice', 0, 0, -12.34, 0, -12.34, nil, nil, nil, nil, nil, nil, nil, -24.68]

      sheet_c = reader["0013 - Division C"]
      expect(sheet_c).to_not be_nil
      expect(sheet_c.length).to eq 17
      expect(sheet_c[0]).to eq [2016, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_c[1]).to eq ['Entries Transmitted', 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
      expect(sheet_c[2]).to eq ['Entry Summary Lines', 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet_c[3]).to eq ['ABI Lines', 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 10]
      expect(sheet_c[4]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 12.34]
      expect(sheet_c[5]).to eq []
      expect(sheet_c[6]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_c[7]).to eq ['Entries Transmitted', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_c[8]).to eq ['Entry Summary Lines', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_c[9]).to eq ['ABI Lines', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_c[10]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet_c[11]).to eq []
      expect(sheet_c[12]).to eq ['Variance', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_c[13]).to eq ['Entries Transmitted', 0, 0, 0, 0, -1, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet_c[14]).to eq ['Entry Summary Lines', 0, 0, 0, 0, -2, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet_c[15]).to eq ['ABI Lines', 0, 0, 0, 0, -10, nil, nil, nil, nil, nil, nil, nil, -10]
      expect(sheet_c[16]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, -12.34, nil, nil, nil, nil, nil, nil, nil, -12.34]

      sheet_d = reader["CA - Toronto"]
      expect(sheet_d).to_not be_nil
      expect(sheet_d.length).to eq 17
      expect(sheet_d[0]).to eq [2016, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_d[1]).to eq ['Entries Transmitted', 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
      expect(sheet_d[2]).to eq ['Entry Summary Lines', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      expect(sheet_d[3]).to eq ['ABI Lines', 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 10]
      expect(sheet_d[4]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 12.34]
      expect(sheet_d[5]).to eq []
      expect(sheet_d[6]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_d[7]).to eq ['Entries Transmitted', 0, 0, 0, 1, 0, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet_d[8]).to eq ['Entry Summary Lines', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_d[9]).to eq ['ABI Lines', 0, 0, 0, 10, 0, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet_d[10]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 12.34, 0.0, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet_d[11]).to eq []
      expect(sheet_d[12]).to eq ['Variance', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_d[13]).to eq ['Entries Transmitted', 0, 0, 0, 1, -1, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_d[14]).to eq ['Entry Summary Lines', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_d[15]).to eq ['ABI Lines', 0, 0, 0, 10, -10, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet_d[16]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 12.34, -12.34, nil, nil, nil, nil, nil, nil, nil, 0.0]
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
      ent_2016_Apr = make_entry '0001', :release_date, make_utc_date(2016, 4, 4)
      ent_2016_Jun = make_entry '0001', :release_date, make_utc_date(2016, 6, 6)

      ent_2017_Mar = make_entry '0001', :release_date, make_utc_date(2017, 3, 2)
      ent_2017_Apr = make_entry '0001', :release_date, make_utc_date(2017, 4, 7)
      ent_2017_Jul = make_entry '0001', :release_date, make_utc_date(2017, 7, 22)

      Timecop.freeze(make_eastern_date(2018, 6, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017'})
      end
      expect(@temp.original_filename).to eq 'Company_YoY_[2016_2017].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 1

      sheet_a = reader["0001 - Division A"]
      expect(sheet_a).to_not be_nil
      expect(sheet_a.length).to eq 17
      expect(sheet_a[0]).to eq [2016, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_a[1]).to eq ['Entries Transmitted', 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet_a[2]).to eq ['Entry Summary Lines', 0, 0, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet_a[3]).to eq ['ABI Lines', 0, 0, 0, 10, 0, 10, 0, 0, 0, 0, 0, 0, 20]
      expect(sheet_a[4]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 12.34, 0.0, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet_a[5]).to eq []
      expect(sheet_a[6]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_a[7]).to eq ['Entries Transmitted', 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 3]
      expect(sheet_a[8]).to eq ['Entry Summary Lines', 0, 0, 2, 2, 0, 0, 2, 0, 0, 0, 0, 0, 6]
      expect(sheet_a[9]).to eq ['ABI Lines', 0, 0, 10, 10, 0, 0, 10, 0, 0, 0, 0, 0, 30]
      expect(sheet_a[10]).to eq ['Total Broker Invoice', 0.0, 0.0, 12.34, 12.34, 0.0, 0.0, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 37.02]
      expect(sheet_a[11]).to eq []
      expect(sheet_a[12]).to eq ['Variance', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet_a[13]).to eq ['Entries Transmitted', 0, 0, 1, 0, 0, -1, 1, 0, 0, 0, 0, 0, 1]
      expect(sheet_a[14]).to eq ['Entry Summary Lines', 0, 0, 2, 0, 0, -2, 2, 0, 0, 0, 0, 0, 2]
      expect(sheet_a[15]).to eq ['ABI Lines', 0, 0, 10, 0, 0, -10, 10, 0, 0, 0, 0, 0, 10]
      expect(sheet_a[16]).to eq ['Total Broker Invoice', 0.0, 0.0, 12.34, 0.0, 0.0, -12.34, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 12.34]
    end

    it "ensures years are in chronological order" do
      ent_2017_Jan_1 = make_entry '0001', :release_date, make_utc_date(2017, 1, 16)
      ent_2017_Jan_2 = make_entry '0001', :release_date, make_utc_date(2017, 1, 17)
      ent_2018_Jan = make_entry '0001', :release_date, make_utc_date(2018, 1, 17)

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        # Report should wind up being ordered 2017 then 2018, not 2018 then 2017.
        @temp = described_class.run_report(u, {'year_1' => '2018', 'year_2' => '2017'})
      end


      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 1

      sheet = reader["0001 - Division A"]
      expect(sheet).to_not be_nil
      expect(sheet.length).to eq 17
      expect(sheet[0]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[1]).to eq ['Entries Transmitted', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[6]).to eq [2018, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[7]).to eq ['Entries Transmitted', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[12]).to eq ['Variance', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[13]).to eq ['Entries Transmitted', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "defaults years when not provided" do
      ent_2017_Jan_1 = make_entry '0001', :release_date, make_utc_date(2017, 1, 16)
      ent_2017_Jan_2 = make_entry '0001', :release_date, make_utc_date(2017, 1, 17)
      ent_2018_Jan = make_entry '0001', :release_date, make_utc_date(2018, 1, 17)

      # These should be excluded because they are outside our date ranges.
      ent_2016_Dec = make_entry '0001', :release_date, make_utc_date(2016, 12, 13)
      ent_2019_Feb = make_entry '0001', :release_date, make_utc_date(2019, 2, 8)

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 1

      sheet = reader["0001 - Division A"]
      expect(sheet).to_not be_nil
      expect(sheet.length).to eq 17
      expect(sheet[0]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[1]).to eq ['Entries Transmitted', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[6]).to eq [2018, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[7]).to eq ['Entries Transmitted', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[12]).to eq ['Variance', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[13]).to eq ['Entries Transmitted', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "appropriate handles null number values" do
      ent_2016_Jan_1 = Factory(:entry, importer_id:importer.id, division_number:'0001', customer_number:'ANYCUST', release_date:make_utc_date(2016, 1, 16), summary_line_count:7)
      ent_2016_Jan_2 = make_entry '0001', :release_date, make_utc_date(2016, 1, 17)
      ent_2017_Jan = Factory(:entry, importer_id:importer.id, division_number:'0001', customer_number:'ANYCUST', release_date:make_utc_date(2017, 1, 1), summary_line_count:8)

      Timecop.freeze(make_eastern_date(2017, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017'})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 1

      sheet = reader["0001 - Division A"]
      expect(sheet).to_not be_nil
      expect(sheet.length).to eq 17
      expect(sheet[0]).to eq [2016, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[1]).to eq ['Entries Transmitted', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[2]).to eq ['Entry Summary Lines', 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3]
      expect(sheet[3]).to eq ['ABI Lines', 17, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17]
      expect(sheet[4]).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 12.34]
      expect(sheet[5]).to eq []
      expect(sheet[6]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[7]).to eq ['Entries Transmitted', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[8]).to eq ['Entry Summary Lines', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[9]).to eq ['ABI Lines', 8, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 8]
      expect(sheet[10]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[11]).to eq []
      expect(sheet[12]).to eq ['Variance', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[13]).to eq ['Entries Transmitted', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[14]).to eq ['Entry Summary Lines', -2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet[15]).to eq ['ABI Lines', -9, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -9]
      expect(sheet[16]).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]
    end

    it "handles UTC time value that falls into another month when converted to eastern" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry '0001', :release_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00")

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018'})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      sheet = reader["0001 - Division A"]
      expect(sheet[1]).to eq ['Entries Transmitted', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "handles UTC time value that falls off the report when converted to eastern" do
      # This should be interpreted as December 2016, and left off the report, not January 2017.
      ent_2016 = make_entry '0001', :release_date, ActiveSupport::TimeZone["UTC"].parse("2017-01-01 02:00")

      # Need to include an entry that is on the report otherwise no report will be generated.
      ent_2017_Feb = make_entry '0001', :release_date, make_utc_date(2017, 2, 2)

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018'})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      sheet = reader["0001 - Division A"]
      expect(sheet[0]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      expect(sheet[1]).to eq ['Entries Transmitted', 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "handles UTC time value that falls into another month when converted to eastern, arrival" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry '0001', :arrival_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00"), customer_number:'EDDIEFTZ'

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018'})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      sheet = reader["0001 - Division A"]
      expect(sheet[1]).to eq ['Entries Transmitted', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "sends email if email address provided" do
      ent_2017_Jan = make_entry '0001', :release_date, make_utc_date(2017, 1, 16)

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'email' => ['a@b.com', 'b@c.dom']})
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['a@b.com', 'b@c.dom']
      expect(mail.subject).to eq "Company YoY Report 2017 vs. 2018"
      expect(mail.body).to include "The VFI year-over-year report is attached, comparing 2017 and 2018."
      expect(mail.attachments.count).to eq 1

      Tempfile.open('attachment') do |t|
        t.binmode
        t << mail.attachments.first.read
        t.flush
        reader = XlsxTestReader.new(t.path).raw_workbook_data
        sheet = reader["0001 - Division A"]
        expect(sheet).to_not be_nil

        expect(sheet.length).to eq 17
        expect(sheet[0]).to eq [2017, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Grand Total (YTD)']
      end
    end
  end

  describe "run_schedulable" do
    it "calls run report method" do
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:run_year_over_year_report).and_return "success"

      expect(described_class.run_schedulable({'email' => 'a@b.com'})).to eq("success")
    end

    it "raises an exception if blank email param is provided" do
      expect(described_class).not_to receive(:new)

      expect { described_class.run_schedulable({'email' => ' '}) }.to raise_error("Email address is required.")
    end

    it "raises an exception if no email param is provided" do
      expect(described_class).not_to receive(:new)

      expect { described_class.run_schedulable({}) }.to raise_error("Email address is required.")
    end
  end

end