describe OpenChain::Report::CustomerYearOverYearReport do

  describe "permission?" do
    let(:ms) { stub_master_setup }
    let (:u) { FactoryBot(:user) }
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
    let (:u) { FactoryBot(:user) }
    let(:importer) { FactoryBot(:company, name:'Crudco Consumables and Poisons, Inc.', system_code:'CRUDCO') }
    let!(:country_us) { FactoryBot(:country, iso_code:'US')}
    let!(:country_ca) { FactoryBot(:country, iso_code:'CA')}

    after { @temp.close if @temp }

    def make_entry counter, entry_type, date_range_field, date_range_field_val, invoice_line_count:2, broker_invoice_isf_charge_count:0, entry_port_code:nil, transport_mode_code:'10', import_country:country_us
      entry = FactoryBot(:entry, customer_number:'ABCD', customer_name:'Crudco', broker_reference:"brok ref #{counter}", summary_line_count:10,
              entry_type:entry_type, entered_value:55.55, total_duty:44.44, mpf:33.33, hmf:22.22, cotton_fee:11.11, total_taxes:9.99,
              other_fees:8.88, total_fees:7.77, arrival_date:make_utc_date(2018, 1, 1+counter), release_date:make_utc_date(2018, 2, 2+counter),
              file_logged_date:make_utc_date(2018, 3, 3+counter), fiscal_date:Date.new(2018, 4, 4+counter),
              eta_date:Date.new(2018, 5, 5+counter), total_units:543.2, total_gst:6.66, total_duty_gst:5.55, export_country_codes:'CN',
              transport_mode_code:transport_mode_code, broker_invoice_total:12.34, importer_id:importer.id,
              entry_port_code:entry_port_code, import_country:import_country)
      entry.update_attributes date_range_field => date_range_field_val
      inv = entry.commercial_invoices.create! invoice_number:"inv-#{entry.id}"
      for i in 1..invoice_line_count
        inv.commercial_invoice_lines.create!
      end
      for i in 1..broker_invoice_isf_charge_count
        b_inv = entry.broker_invoices.create! invoice_number:"inv-#{entry.id}-#{i}"
        b_inv.broker_invoice_lines.create! charge_code:'0191', charge_amount:1.11, charge_description:'ISF Charge'
        b_inv.broker_invoice_lines.create! charge_code:'NOPE', charge_amount:5.43, charge_description:'Some Other Charge'
      end
      entry
    end

    it "generates spreadsheet based on arrival date" do
      port_a = FactoryBot(:port, schedule_d_code:'5678', name:'Port A')
      port_b = FactoryBot(:port, cbsa_port:'6789', name:'Port B')

      ent_2016_Feb_1 = make_entry 1, '01', :arrival_date, make_utc_date(2016, 2, 16), invoice_line_count:3, broker_invoice_isf_charge_count:2, transport_mode_code:'10'
      ent_2016_Feb_2 = make_entry 2, '01', :arrival_date, make_utc_date(2016, 2, 17), invoice_line_count:5, broker_invoice_isf_charge_count:1, transport_mode_code:'9'
      ent_2016_Mar = make_entry 3, '02', :arrival_date, make_utc_date(2016, 3, 3), broker_invoice_isf_charge_count:1, transport_mode_code:'40'
      ent_2016_Apr_1 = make_entry 4, '01', :arrival_date, make_utc_date(2016, 4, 4), transport_mode_code:'41'
      ent_2016_Apr_2 = make_entry 5, '02', :arrival_date, make_utc_date(2016, 4, 16), transport_mode_code:'40'
      ent_2016_Apr_3 = make_entry 6, '01', :arrival_date, make_utc_date(2016, 4, 25), transport_mode_code:'30'
      ent_2016_May = make_entry 7, '13', :arrival_date, make_utc_date(2016, 5, 15), transport_mode_code:'666'
      ent_2016_Jun = make_entry 8, '02', :arrival_date, make_utc_date(2016, 6, 6), transport_mode_code:'40'

      ent_2017_Jan_1 = make_entry 9, '01', :arrival_date, make_utc_date(2017, 1, 1), transport_mode_code:'10'
      ent_2017_Jan_2 = make_entry 10, '01', :arrival_date, make_utc_date(2017, 1, 17), transport_mode_code:'11'
      ent_2017_Mar = make_entry 11, '01', :arrival_date, make_utc_date(2017, 3, 2), broker_invoice_isf_charge_count:2, transport_mode_code:'40'
      ent_2017_Apr = make_entry 12, '01', :arrival_date, make_utc_date(2017, 4, 7), transport_mode_code:'20'
      ent_2017_May_1 = make_entry 13, '01', :arrival_date, make_utc_date(2017, 5, 21), transport_mode_code:'21', broker_invoice_isf_charge_count:3, entry_port_code:'6789', import_country:country_ca
      ent_2017_May_2 = make_entry 14, '01', :arrival_date, make_utc_date(2017, 5, 22), transport_mode_code:'10', broker_invoice_isf_charge_count:1, entry_port_code:'5678'
      ent_2017_May_3 = make_entry 15, '02', :arrival_date, make_utc_date(2017, 5, 27), broker_invoice_isf_charge_count:1, entry_port_code:'6789', import_country:country_ca
      ent_2017_May_4 = make_entry 16, '02', :arrival_date, make_utc_date(2017, 5, 28), broker_invoice_isf_charge_count:1, entry_port_code:nil
      ent_2017_May_5 = make_entry 17, '01', :arrival_date, make_utc_date(2017, 5, 29), broker_invoice_isf_charge_count:1, entry_port_code:'6789', import_country:country_ca
      ent_2017_May_6 = make_entry 18, '01', :arrival_date, make_utc_date(2017, 5, 30), broker_invoice_isf_charge_count:1, entry_port_code:'No Match'

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 19, '01', :arrival_date, make_utc_date(2015, 12, 13)
      ent_2018_Feb = make_entry 20, '01', :arrival_date, make_utc_date(2018, 2, 8)

      # This should be excluded because it belongs to a different importer.
      ent_2016_Feb_different_importer = make_entry 21, '01', :arrival_date, make_utc_date(2016, 2, 11)
      importer_2 = FactoryBot(:company, name:'Crudco Bitter Rival')
      ent_2016_Feb_different_importer.update_attributes :importer_id => importer_2.id

      Timecop.freeze(make_eastern_date(2017, 6, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'arrival_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => true, 'include_taxes' => true, 'include_other_fees' => true, 'include_isf_fees' => true, 'include_port_breakdown' => true, 'group_by_mode_of_transport' => true, 'include_line_graphs' => true, 'sum_units_by_mode_of_transport' => true})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_arrival_date_[2016_2017].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 3

      # Tab name should have been truncated.  Company name is too long to fit.
      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet).to_not be_nil
      expect(sheet.length).to eq 90
      expect(sheet[0]).to eq []
      expect(sheet[1]).to eq []
      expect(sheet[2]).to eq []
      expect(sheet[3]).to eq []
      expect(sheet[4]).to eq [2016, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 0, 2, 1, 3, 1, 1, 0, 0, 0, 0, 0, 0, 8]
      expect(sheet[6]).to eq ['Entry Summary Lines', 0, 8, 2, 6, 2, 2, 0, 0, 0, 0, 0, 0, 20]
      expect(sheet[7]).to eq ['Total Units', 0, 1086.4, 543.2, 1629.6, 543.2, 543.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4345.6]
      expect(sheet[8]).to eq ['Entry Type 01', 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet[9]).to eq ['Entry Type 02', 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 3]
      expect(sheet[10]).to eq ['Entry Type 13', 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
      expect(sheet[11]).to eq ['Ship Mode Air', 0, 0, 1, 2, 0, 1, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet[12]).to eq ['Ship Mode Rail', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      expect(sheet[13]).to eq ['Ship Mode Sea', 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[14]).to eq ['Ship Mode Truck', 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
      expect(sheet[15]).to eq ['Ship Mode N/A', 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
      expect(sheet[16]).to eq ['Ship Mode Air (Units)', 0, 0, 543.2, 1086.4, 0, 543.2, 0, 0, 0, 0, 0, 0, 2172.8]
      expect(sheet[17]).to eq ['Ship Mode Rail (Units)', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      expect(sheet[18]).to eq ['Ship Mode Sea (Units)', 0, 1086.4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1086.4]
      expect(sheet[19]).to eq ['Ship Mode Truck (Units)', 0, 0, 0, 543.2, 0, 0, 0, 0, 0, 0, 0, 0, 543.2]
      expect(sheet[20]).to eq ['Ship Mode N/A (Units)', 0, 0, 0, 0, 543.2, 0, 0, 0, 0, 0, 0, 0, 543.2]
      expect(sheet[21]).to eq ['Total Entered Value', 0.0, 111.1, 55.55, 166.65, 55.55, 55.55, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 444.4]
      expect(sheet[22]).to eq ['Total Duty', 0.0, 88.88, 44.44, 133.32, 44.44, 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 355.52]
      expect(sheet[23]).to eq ['MPF', 0.0, 66.66, 33.33, 99.99, 33.33, 33.33, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 266.64]
      expect(sheet[24]).to eq ['HMF', 0.0, 44.44, 22.22, 66.66, 22.22, 22.22, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 177.76]
      expect(sheet[25]).to eq ['Cotton Fee', 0.0, 22.22, 11.11, 33.33, 11.11, 11.11, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet[26]).to eq ['Total Taxes', 0.0, 19.98, 9.99, 29.97, 9.99, 9.99, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 79.92]
      expect(sheet[27]).to eq ['Other Fees', 0, 17.76, 8.88, 26.64, 8.88, 8.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 71.04]
      expect(sheet[28]).to eq ['Total Fees', 0.0, 15.54, 7.77, 23.31, 7.77, 7.77, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 62.16]
      expect(sheet[29]).to eq ['Total Duty & Fees', 0.0, 104.42, 52.21, 156.63, 52.21, 52.21, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 417.68]
      expect(sheet[30]).to eq ['Total Broker Invoice', 0.0, 24.68, 12.34, 37.02, 12.34, 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 98.72]
      expect(sheet[31]).to eq ['ISF Fees', 0.0, 3.33, 1.11, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.44]
      expect(sheet[32]).to eq []
      expect(sheet[33]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[34]).to eq ['Number of Entries', 2, 0, 1, 1, 6, nil, nil, nil, nil, nil, nil, nil, 10]
      expect(sheet[35]).to eq ['Entry Summary Lines', 4, 0, 2, 2, 12, nil, nil, nil, nil, nil, nil, nil, 20]
      expect(sheet[36]).to eq ['Total Units', 1086.4, 0.0, 543.2, 543.2, 3259.2, nil, nil, nil, nil, nil, nil, nil, 5432.0]
      expect(sheet[37]).to eq ['Entry Type 01', 2, 0, 1, 1, 4, nil, nil, nil, nil, nil, nil, nil, 8]
      expect(sheet[38]).to eq ['Entry Type 02', 0, 0, 0, 0, 2, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet[39]).to eq ['Entry Type 13', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[40]).to eq ['Ship Mode Air', 0, 0, 1, 0, 0, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[41]).to eq ['Ship Mode Rail', 0, 0, 0, 1, 1, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet[42]).to eq ['Ship Mode Sea', 2, 0, 0, 0, 5, nil, nil, nil, nil, nil, nil, nil, 7]
      expect(sheet[43]).to eq ['Ship Mode Truck', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[44]).to eq ['Ship Mode N/A', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[45]).to eq ['Ship Mode Air (Units)', 0, 0, 543.2, 0, 0, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet[46]).to eq ['Ship Mode Rail (Units)', 0, 0, 0, 543.2, 543.2, nil, nil, nil, nil, nil, nil, nil, 1086.4]
      expect(sheet[47]).to eq ['Ship Mode Sea (Units)', 1086.4, 0, 0, 0, 2716.0, nil, nil, nil, nil, nil, nil, nil, 3802.4]
      expect(sheet[48]).to eq ['Ship Mode Truck (Units)', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[49]).to eq ['Ship Mode N/A (Units)', 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[50]).to eq ['Total Entered Value', 111.1, 0.0, 55.55, 55.55, 333.3, nil, nil, nil, nil, nil, nil, nil, 555.5]
      expect(sheet[51]).to eq ['Total Duty', 88.88, 0.0, 44.44, 44.44, 266.64, nil, nil, nil, nil, nil, nil, nil, 444.4]
      expect(sheet[52]).to eq ['MPF', 66.66, 0.0, 33.33, 33.33, 199.98, nil, nil, nil, nil, nil, nil, nil, 333.3]
      expect(sheet[53]).to eq ['HMF', 44.44, 0.0, 22.22, 22.22, 133.32, nil, nil, nil, nil, nil, nil, nil, 222.2]
      expect(sheet[54]).to eq ['Cotton Fee', 22.22, 0.0, 11.11, 11.11, 66.66, nil, nil, nil, nil, nil, nil, nil, 111.1]
      expect(sheet[55]).to eq ['Total Taxes', 19.98, 0.0, 9.99, 9.99, 59.94, nil, nil, nil, nil, nil, nil, nil, 99.9]
      expect(sheet[56]).to eq ['Other Fees', 17.76, 0.0, 8.88, 8.88, 53.28, nil, nil, nil, nil, nil, nil, nil, 88.8]
      expect(sheet[57]).to eq ['Total Fees', 15.54, 0.0, 7.77, 7.77, 46.62, nil, nil, nil, nil, nil, nil, nil, 77.7]
      expect(sheet[58]).to eq ['Total Duty & Fees', 104.42, 0.0, 52.21, 52.21, 313.26, nil, nil, nil, nil, nil, nil, nil, 522.1]
      expect(sheet[59]).to eq ['Total Broker Invoice', 24.68, 0.0, 12.34, 12.34, 74.04, nil, nil, nil, nil, nil, nil, nil, 123.4]
      expect(sheet[60]).to eq ['ISF Fees', 0.0, 0.0, 2.22, 0.0, 8.88, nil, nil, nil, nil, nil, nil, nil, 11.1]
      expect(sheet[61]).to eq []
      expect(sheet[62]).to eq ['Variance 2016 / 2017', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[63]).to eq ['Number of Entries', 2, -2, 0, -2, 5, nil, nil, nil, nil, nil, nil, nil, 3]
      expect(sheet[64]).to eq ['Entry Summary Lines', 4, -8, 0, -4, 10, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet[65]).to eq ['Total Units', 1086.4, -1086.4, 0.0, -1086.4, 2716.0, nil, nil, nil, nil, nil, nil, nil, 1629.6]
      expect(sheet[66]).to eq ['Entry Type 01', 2, -2, 1, -1, 4, nil, nil, nil, nil, nil, nil, nil, 4]
      expect(sheet[67]).to eq ['Entry Type 02', 0, 0, -1, -1, 2, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[68]).to eq ['Entry Type 13', 0, 0, 0, 0, -1, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[69]).to eq ['Ship Mode Air', 0, 0, 0, -2, 0, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet[70]).to eq ['Ship Mode Rail', 0, 0, 0, 1, 1, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet[71]).to eq ['Ship Mode Sea', 2, -2, 0, 0, 5, nil, nil, nil, nil, nil, nil, nil, 5]
      expect(sheet[72]).to eq ['Ship Mode Truck', 0, 0, 0, -1, 0, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[73]).to eq ['Ship Mode N/A', 0, 0, 0, 0, -1, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[74]).to eq ['Ship Mode Air (Units)', 0, 0, 0.0, -1086.4, 0, nil, nil, nil, nil, nil, nil, nil, -1086.4]
      expect(sheet[75]).to eq ['Ship Mode Rail (Units)', 0, 0, 0, 543.2, 543.2, nil, nil, nil, nil, nil, nil, nil, 1086.4]
      expect(sheet[76]).to eq ['Ship Mode Sea (Units)', 1086.4, -1086.4, 0, 0, 2716.0, nil, nil, nil, nil, nil, nil, nil, 2716.0]
      expect(sheet[77]).to eq ['Ship Mode Truck (Units)', 0, 0, 0, -543.2, 0, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet[78]).to eq ['Ship Mode N/A (Units)', 0, 0, 0, 0, -543.2, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet[79]).to eq ['Total Entered Value', 111.1, -111.1, 0.0, -111.1, 277.75, nil, nil, nil, nil, nil, nil, nil, 166.65]
      expect(sheet[80]).to eq ['Total Duty', 88.88, -88.88, 0.0, -88.88, 222.2, nil, nil, nil, nil, nil, nil, nil, 133.32]
      expect(sheet[81]).to eq ['MPF', 66.66, -66.66, 0.0, -66.66, 166.65, nil, nil, nil, nil, nil, nil, nil, 99.99]
      expect(sheet[82]).to eq ['HMF', 44.44, -44.44, 0.0, -44.44, 111.1, nil, nil, nil, nil, nil, nil, nil, 66.66]
      expect(sheet[83]).to eq ['Cotton Fee', 22.22, -22.22, 0.0, -22.22, 55.55, nil, nil, nil, nil, nil, nil, nil, 33.33]
      expect(sheet[84]).to eq ['Total Taxes', 19.98, -19.98, 0.0, -19.98, 49.95, nil, nil, nil, nil, nil, nil, nil, 29.97]
      expect(sheet[85]).to eq ['Other Fees', 17.76, -17.76, 0.0, -17.76, 44.4, nil, nil, nil, nil, nil, nil, nil, 26.64]
      expect(sheet[86]).to eq ['Total Fees', 15.54, -15.54, 0.0, -15.54, 38.85, nil, nil, nil, nil, nil, nil, nil, 23.31]
      expect(sheet[87]).to eq ['Total Duty & Fees', 104.42, -104.42, 0.0, -104.42, 261.05, nil, nil, nil, nil, nil, nil, nil, 156.63]
      expect(sheet[88]).to eq ['Total Broker Invoice', 24.68, -24.68, 0.0, -24.68, 61.7, nil, nil, nil, nil, nil, nil, nil, 37.02]
      expect(sheet[89]).to eq ['ISF Fees', 0.0, -3.33, 1.11, 0.0, 8.88, nil, nil, nil, nil, nil, nil, nil, 6.66]

      raw_sheet = reader["Data"]
      expect(raw_sheet).to_not be_nil
      expect(raw_sheet.length).to eq 19
      expect(raw_sheet[0]).to eq ['Customer Number', 'Customer Name', 'Broker Reference', 'Entry Summary Line Count',
                                      'Entry Type', 'Total Entered Value', 'Total Duty', 'MPF', 'HMF', 'Cotton Fee',
                                      'Total Taxes', 'Other Taxes & Fees', 'Total Fees', 'Arrival Date', 'Release Date',
                                      'File Logged Date', 'Fiscal Date', 'ETA Date', 'Total Units',
                                      'Country Export Codes', 'Mode of Transport', 'Total Broker Invoice', 'ISF Fees',
                                      'Port of Entry Code']
      expect(raw_sheet[1]).to eq ['ABCD', 'Crudco', 'brok ref 1', 3, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2016, 2, 16), Date.new(2018, 2, 3), Date.new(2018, 3, 4), Date.new(2018, 4, 5), Date.new(2018, 5, 6), 543.2, 'CN', '10', 12.34, 2.22, nil]
      expect(raw_sheet[2]).to eq ['ABCD', 'Crudco', 'brok ref 2', 5, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2016, 2, 17), Date.new(2018, 2, 4), Date.new(2018, 3, 5), Date.new(2018, 4, 6), Date.new(2018, 5, 7), 543.2, 'CN', '9', 12.34, 1.11, nil]
      expect(raw_sheet[3]).to eq ['ABCD', 'Crudco', 'brok ref 3', 2, '02', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2016, 3, 3), Date.new(2018, 2, 5), Date.new(2018, 3, 6), Date.new(2018, 4, 7), Date.new(2018, 5, 8), 543.2, 'CN', '40', 12.34, 1.11, nil]
      expect(raw_sheet[4]).to eq ['ABCD', 'Crudco', 'brok ref 4', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2016, 4, 4), Date.new(2018, 2, 6), Date.new(2018, 3, 7), Date.new(2018, 4, 8), Date.new(2018, 5, 9), 543.2, 'CN', '41', 12.34, 0.00, nil]
      expect(raw_sheet[5]).to eq ['ABCD', 'Crudco', 'brok ref 5', 2, '02', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2016, 4, 16), Date.new(2018, 2, 7), Date.new(2018, 3, 8), Date.new(2018, 4, 9), Date.new(2018, 5, 10), 543.2, 'CN', '40', 12.34, 0.00, nil]
      expect(raw_sheet[6]).to eq ['ABCD', 'Crudco', 'brok ref 6', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2016, 4, 25), Date.new(2018, 2, 8), Date.new(2018, 3, 9), Date.new(2018, 4, 10), Date.new(2018, 5, 11), 543.2, 'CN', '30', 12.34, 0.00, nil]
      expect(raw_sheet[7]).to eq ['ABCD', 'Crudco', 'brok ref 7', 2, '13', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2016, 5, 15), Date.new(2018, 2, 9), Date.new(2018, 3, 10), Date.new(2018, 4, 11), Date.new(2018, 5, 12), 543.2, 'CN', '666', 12.34, 0.00, nil]
      expect(raw_sheet[8]).to eq ['ABCD', 'Crudco', 'brok ref 8', 2, '02', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2016, 6, 6), Date.new(2018, 2, 10), Date.new(2018, 3, 11), Date.new(2018, 4, 12), Date.new(2018, 5, 13), 543.2, 'CN', '40', 12.34, 0.00, nil]
      expect(raw_sheet[9]).to eq ['ABCD', 'Crudco', 'brok ref 9', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 1, 1), Date.new(2018, 2, 11), Date.new(2018, 3, 12), Date.new(2018, 4, 13), Date.new(2018, 5, 14), 543.2, 'CN', '10', 12.34, 0.00, nil]
      expect(raw_sheet[10]).to eq ['ABCD', 'Crudco', 'brok ref 10', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 1, 17), Date.new(2018, 2, 12), Date.new(2018, 3, 13), Date.new(2018, 4, 14), Date.new(2018, 5, 15), 543.2, 'CN', '11', 12.34, 0.00, nil]
      expect(raw_sheet[11]).to eq ['ABCD', 'Crudco', 'brok ref 11', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 3, 2), Date.new(2018, 2, 13), Date.new(2018, 3, 14), Date.new(2018, 4, 15), Date.new(2018, 5, 16), 543.2, 'CN', '40', 12.34, 2.22, nil]
      expect(raw_sheet[12]).to eq ['ABCD', 'Crudco', 'brok ref 12', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 4, 7), Date.new(2018, 2, 14), Date.new(2018, 3, 15), Date.new(2018, 4, 16), Date.new(2018, 5, 17), 543.2, 'CN', '20', 12.34, 0.00, nil]
      expect(raw_sheet[13]).to eq ['ABCD', 'Crudco', 'brok ref 13', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 5, 21), Date.new(2018, 2, 15), Date.new(2018, 3, 16), Date.new(2018, 4, 17), Date.new(2018, 5, 18), 543.2, 'CN', '21', 12.34, 3.33, '6789']
      expect(raw_sheet[14]).to eq ['ABCD', 'Crudco', 'brok ref 14', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 5, 22), Date.new(2018, 2, 16), Date.new(2018, 3, 17), Date.new(2018, 4, 18), Date.new(2018, 5, 19), 543.2, 'CN', '10', 12.34, 1.11, '5678']
      expect(raw_sheet[15]).to eq ['ABCD', 'Crudco', 'brok ref 15', 2, '02', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 5, 27), Date.new(2018, 2, 17), Date.new(2018, 3, 18), Date.new(2018, 4, 19), Date.new(2018, 5, 20), 543.2, 'CN', '10', 12.34, 1.11, '6789']
      expect(raw_sheet[16]).to eq ['ABCD', 'Crudco', 'brok ref 16', 2, '02', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 5, 28), Date.new(2018, 2, 18), Date.new(2018, 3, 19), Date.new(2018, 4, 20), Date.new(2018, 5, 21), 543.2, 'CN', '10', 12.34, 1.11, nil]
      expect(raw_sheet[17]).to eq ['ABCD', 'Crudco', 'brok ref 17', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 5, 29), Date.new(2018, 2, 19), Date.new(2018, 3, 20), Date.new(2018, 4, 21), Date.new(2018, 5, 22), 543.2, 'CN', '10', 12.34, 1.11, '6789']
      expect(raw_sheet[18]).to eq ['ABCD', 'Crudco', 'brok ref 18', 2, '01', 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, Date.new(2017, 5, 30), Date.new(2018, 2, 20), Date.new(2018, 3, 21), Date.new(2018, 4, 22), Date.new(2018, 5, 23), 543.2, 'CN', '10', 12.34, 1.11, 'No Match']

      port_sheet = reader["Port Breakdown"]
      expect(port_sheet).to_not be_nil
      expect(port_sheet.length).to eq 5
      expect(port_sheet[0]).to eq ['June 2017 Port Breakdown', 'Entry Port Code', 'Number of Entries', 'Entry Summary Lines',
                                      'Total Units', 'Entry Type 01', 'Entry Type 02', 'Total Entered Value', 'Total Duty',
                                      'MPF', 'HMF', 'Cotton Fee', 'Total Taxes', 'Other Taxes & Fees', 'Total Fees',
                                      'Total Broker Invoice', 'ISF Fees']
      expect(port_sheet[1]).to eq ['Port A', '5678', 1, 2, 543.2, 1, 0, 55.55, 44.44, 33.33, 22.22, 11.11, 9.99, 8.88, 7.77, 12.34, 1.11]
      expect(port_sheet[2]).to eq ['Port B', '6789', 3, 6, 1629.6, 2, 1, 166.65, 133.32, 99.99, 66.66, 33.33, 29.97, 26.64, 23.31, 37.02, 5.55]
      expect(port_sheet[3]).to eq ['N/A', 'N/A', 2, 4, 1086.4, 1, 1, 111.1, 88.88, 66.66, 44.44, 22.22, 19.98, 17.76, 15.54, 24.68, 2.22]
      expect(port_sheet[4]).to eq ['Grand Totals', nil, 6, 12, 3259.2, 4, 2, 333.3, 266.64, 199.98, 133.32, 66.66, 59.94, 53.28, 46.62, 74.04, 8.88]
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
      port_a = FactoryBot(:port, schedule_d_code:'5678', name:'Port A')

      ent_2016_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2016, 1, 16)
      ent_2016_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2016, 1, 17)
      ent_2017_Jan = make_entry 3, '01', :eta_date, make_utc_date(2017, 1, 17)
      ent_2017_Apr_1 = make_entry 6, '01', :eta_date, make_utc_date(2017, 4, 6), broker_invoice_isf_charge_count:1, entry_port_code:'5678'
      ent_2017_Apr_2 = make_entry 7, '01', :eta_date, make_utc_date(2017, 4, 7), broker_invoice_isf_charge_count:1, entry_port_code:'5678'

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 4, '01', :eta_date, make_utc_date(2015, 12, 13)
      ent_2018_Feb = make_entry 5, '01', :eta_date, make_utc_date(2018, 2, 8)

      Timecop.freeze(make_eastern_date(2017, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false, 'include_isf_fees' => false, 'include_port_breakdown' => true})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_eta_date_[2016_2017].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 3

      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 42
      expect(sheet[4]).to eq [2016, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[6]).to eq ['Entry Summary Lines', 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet[7]).to eq ['Total Units', 1086.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1086.4]
      expect(sheet[8]).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[9]).to eq ['Total Entered Value', 111.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.1]
      expect(sheet[10]).to eq ['Total Duty', 88.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet[11]).to eq ['MPF', 66.66, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 66.66]
      expect(sheet[12]).to eq ['HMF', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet[13]).to eq ['Total Fees', 15.54, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 15.54]
      expect(sheet[14]).to eq ['Total Duty & Fees', 104.42, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 104.42]
      expect(sheet[15]).to eq ['Total Broker Invoice', 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet[16]).to eq []
      expect(sheet[17]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[18]).to eq ['Number of Entries', 1, 0, 0, 2, nil, nil, nil, nil, nil, nil, nil, nil, 3]
      expect(sheet[19]).to eq ['Entry Summary Lines', 2, 0, 0, 4, nil, nil, nil, nil, nil, nil, nil, nil, 6]
      expect(sheet[20]).to eq ['Total Units', 543.2, 0.0, 0.0, 1086.4, nil, nil, nil, nil, nil, nil, nil, nil, 1629.6]
      expect(sheet[21]).to eq ['Entry Type 01', 1, 0, 0, 2, nil, nil, nil, nil, nil, nil, nil, nil, 3]
      expect(sheet[22]).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 111.1, nil, nil, nil, nil, nil, nil, nil, nil, 166.65]
      expect(sheet[23]).to eq ['Total Duty', 44.44, 0.0, 0.0, 88.88, nil, nil, nil, nil, nil, nil, nil, nil, 133.32]
      expect(sheet[24]).to eq ['MPF', 33.33, 0.0, 0.0, 66.66, nil, nil, nil, nil, nil, nil, nil, nil, 99.99]
      expect(sheet[25]).to eq ['HMF', 22.22, 0.0, 0.0, 44.44, nil, nil, nil, nil, nil, nil, nil, nil, 66.66]
      expect(sheet[26]).to eq ['Total Fees', 7.77, 0.0, 0.0, 15.54, nil, nil, nil, nil, nil, nil, nil, nil, 23.31]
      expect(sheet[27]).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 104.42, nil, nil, nil, nil, nil, nil, nil, nil, 156.63]
      expect(sheet[28]).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 24.68, nil, nil, nil, nil, nil, nil, nil, nil, 37.02]
      expect(sheet[29]).to eq []
      expect(sheet[30]).to eq ['Variance 2016 / 2017', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[31]).to eq ['Number of Entries', -1, 0, 0, 2, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[32]).to eq ['Entry Summary Lines', -2, 0, 0, 4, nil, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet[33]).to eq ['Total Units', -543.2, 0.0, 0.0, 1086.4, nil, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet[34]).to eq ['Entry Type 01', -1, 0, 0, 2, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[35]).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 111.1, nil, nil, nil, nil, nil, nil, nil, nil, 55.55]
      expect(sheet[36]).to eq ['Total Duty', -44.44, 0.0, 0.0, 88.88, nil, nil, nil, nil, nil, nil, nil, nil, 44.44]
      expect(sheet[37]).to eq ['MPF', -33.33, 0.0, 0.0, 66.66, nil, nil, nil, nil, nil, nil, nil, nil, 33.33]
      expect(sheet[38]).to eq ['HMF', -22.22, 0.0, 0.0, 44.44, nil, nil, nil, nil, nil, nil, nil, nil, 22.22]
      expect(sheet[39]).to eq ['Total Fees', -7.77, 0.0, 0.0, 15.54, nil, nil, nil, nil, nil, nil, nil, nil, 7.77]
      expect(sheet[40]).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 104.42, nil, nil, nil, nil, nil, nil, nil, nil, 52.21]
      expect(sheet[41]).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 24.68, nil, nil, nil, nil, nil, nil, nil, nil, 12.34]

      raw_sheet = reader["Data"]
      expect(raw_sheet.length).to eq 6

      port_sheet = reader["Port Breakdown"]
      expect(port_sheet.length).to eq 3
      expect(port_sheet[0]).to eq ['May 2017 Port Breakdown', 'Entry Port Code', 'Number of Entries', 'Entry Summary Lines',
                                       'Total Units', 'Entry Type 01', 'Total Entered Value', 'Total Duty', 'MPF', 'HMF',
                                       'Total Fees', 'Total Broker Invoice']
      expect(port_sheet[1]).to eq ["Port A", "5678", 2, 4, 1086.4, 2, 111.1, 88.88, 66.66, 44.44, 15.54, 24.68]
      expect(port_sheet[2]).to eq ['Grand Totals', nil, 2, 4, 1086.4, 2, 111.1, 88.88, 66.66, 44.44, 15.54, 24.68]
    end

    it "generates spreadsheet with Canada fields" do
      port_a = FactoryBot(:port, schedule_d_code:'5678', name:'Port A')

      ent_2016_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2016, 1, 16)
      ent_2016_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2016, 1, 17)
      ent_2017_Jan = make_entry 3, '01', :eta_date, make_utc_date(2017, 1, 17)
      ent_2017_Apr_1 = make_entry 6, '01', :eta_date, make_utc_date(2017, 4, 6), broker_invoice_isf_charge_count:1, entry_port_code:'5678'
      ent_2017_Apr_2 = make_entry 7, '01', :eta_date, make_utc_date(2017, 4, 7), broker_invoice_isf_charge_count:1, entry_port_code:'5678'

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 4, '01', :eta_date, make_utc_date(2015, 12, 13)
      ent_2018_Feb = make_entry 5, '01', :eta_date, make_utc_date(2018, 2, 8)

      Timecop.freeze(make_eastern_date(2017, 5, 28)) do
        @temp = described_class.run_report(u, {'ca' => true, 'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false, 'include_isf_fees' => false, 'include_port_breakdown' => true})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_eta_date_[2016_2017].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 3

      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 36
      expect(sheet[4]).to eq [2016, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[6]).to eq ['Entry Summary Lines', 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet[7]).to eq ['Total Units', 1086.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1086.4]
      expect(sheet[8]).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[9]).to eq ['Total Entered Value', 111.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.1]
      expect(sheet[10]).to eq ['Total Duty', 88.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet[11]).to eq ['Total Broker Invoice', 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet[12]).to eq ['Total GST', 13.32, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 13.32]
      expect(sheet[13]).to eq ['Total Duty & GST', 11.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 11.1]
      expect(sheet[14]).to eq []
      expect(sheet[15]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[16]).to eq ['Number of Entries', 1, 0, 0, 2, nil, nil, nil, nil, nil, nil, nil, nil, 3]
      expect(sheet[17]).to eq ['Entry Summary Lines', 2, 0, 0, 4, nil, nil, nil, nil, nil, nil, nil, nil, 6]
      expect(sheet[18]).to eq ['Total Units', 543.2, 0.0, 0.0, 1086.4, nil, nil, nil, nil, nil, nil, nil, nil, 1629.6]
      expect(sheet[19]).to eq ['Entry Type 01', 1, 0, 0, 2, nil, nil, nil, nil, nil, nil, nil, nil, 3]
      expect(sheet[20]).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 111.1, nil, nil, nil, nil, nil, nil, nil, nil, 166.65]
      expect(sheet[21]).to eq ['Total Duty', 44.44, 0.0, 0.0, 88.88, nil, nil, nil, nil, nil, nil, nil, nil, 133.32]
      expect(sheet[22]).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 24.68, nil, nil, nil, nil, nil, nil, nil, nil, 37.02]
      expect(sheet[23]).to eq ['Total GST', 6.66, 0.0, 0.0, 13.32, nil, nil, nil, nil, nil, nil, nil, nil, 19.98]
      expect(sheet[24]).to eq ['Total Duty & GST', 5.55, 0.0, 0.0, 11.1, nil, nil, nil, nil, nil, nil, nil, nil, 16.65]
      expect(sheet[25]).to eq []
      expect(sheet[26]).to eq ['Variance 2016 / 2017', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[27]).to eq ['Number of Entries', -1, 0, 0, 2, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[28]).to eq ['Entry Summary Lines', -2, 0, 0, 4, nil, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet[29]).to eq ['Total Units', -543.2, 0.0, 0.0, 1086.4, nil, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet[30]).to eq ['Entry Type 01', -1, 0, 0, 2, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[31]).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 111.1, nil, nil, nil, nil, nil, nil, nil, nil, 55.55]
      expect(sheet[32]).to eq ['Total Duty', -44.44, 0.0, 0.0, 88.88, nil, nil, nil, nil, nil, nil, nil, nil, 44.44]
      expect(sheet[33]).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 24.68, nil, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet[34]).to eq ['Total GST', -6.66, 0.0, 0.0, 13.32, nil, nil, nil, nil, nil, nil, nil, nil, 6.66]
      expect(sheet[35]).to eq ['Total Duty & GST', -5.55, 0.0, 0.0, 11.1, nil, nil, nil, nil, nil, nil, nil, nil, 5.55]

      raw_sheet = reader["Data"]
      expect(raw_sheet.length).to eq 6

      expect(raw_sheet[0]).to eq ['Customer Number', 'Customer Name', 'Broker Reference', 'Entry Summary Line Count',
                                  'Entry Type', 'Total Entered Value', 'Total Duty', 'Arrival Date', 'Release Date',
                                  'File Logged Date', 'Fiscal Date', 'ETA Date', 'Total Units', 'Total GST', 'Total Duty & GST',
                                  'Country Export Codes', 'Mode of Transport', 'Total Broker Invoice', 'Port of Entry Code']
      expect(raw_sheet[1]).to eq ['ABCD', 'Crudco', 'brok ref 1', 2, '01', 55.55, 44.44, Date.new(2018, 1, 2), Date.new(2018, 2, 3), Date.new(2018, 3, 4), Date.new(2018, 4, 5), Date.new(2016, 1, 16), 543.2, 6.66, 5.55, 'CN', '10', 12.34, nil]
      expect(raw_sheet[2]).to eq ['ABCD', 'Crudco', 'brok ref 2', 2, '01', 55.55, 44.44, Date.new(2018, 1, 3), Date.new(2018, 2, 4), Date.new(2018, 3, 5), Date.new(2018, 4, 6), Date.new(2016, 1, 17), 543.2, 6.66, 5.55, 'CN', '10', 12.34, nil]
      expect(raw_sheet[3]).to eq ['ABCD', 'Crudco', 'brok ref 3', 2, '01', 55.55, 44.44, Date.new(2018, 1, 4), Date.new(2018, 2, 5), Date.new(2018, 3, 6), Date.new(2018, 4, 7), Date.new(2017, 1, 17), 543.2, 6.66, 5.55, 'CN', '10', 12.34, nil]
      expect(raw_sheet[4]).to eq ['ABCD', 'Crudco', 'brok ref 6', 2, '01', 55.55, 44.44, Date.new(2018, 1, 7), Date.new(2018, 2, 8), Date.new(2018, 3, 9), Date.new(2018, 4, 10), Date.new(2017, 4, 6), 543.2, 6.66, 5.55, 'CN', '10', 12.34, "5678"]
      expect(raw_sheet[5]).to eq ['ABCD', 'Crudco', 'brok ref 7', 2, '01', 55.55, 44.44, Date.new(2018, 1, 8), Date.new(2018, 2, 9), Date.new(2018, 3, 10), Date.new(2018, 4, 11), Date.new(2017, 4, 7), 543.2, 6.66, 5.55, 'CN', '10', 12.34, "5678"]

      port_sheet = reader["Port Breakdown"]
      expect(port_sheet.length).to eq 3
      expect(port_sheet[0]).to eq ['May 2017 Port Breakdown', 'Entry Port Code', 'Number of Entries', 'Entry Summary Lines',
                                   'Total Units', 'Entry Type 01', 'Total Entered Value', 'Total Duty', 'Total Broker Invoice',
                                   'Total GST', 'Total Duty & GST']
      expect(port_sheet[1]).to eq ["Port A", "5678", 2, 4, 1086.4, 2, 111.1, 88.88, 24.68, 13.32, 11.1]
      expect(port_sheet[2]).to eq ['Grand Totals', nil, 2, 4, 1086.4, 2, 111.1, 88.88, 24.68, 13.32, 11.1]
    end

    it "generates spreadsheet based on file logged date" do
      ent_2016_Jan_1 = make_entry 1, '01', :file_logged_date, make_utc_date(2016, 1, 16)
      ent_2016_Jan_2 = make_entry 2, '01', :file_logged_date, make_utc_date(2016, 1, 17)
      ent_2017_Jan = make_entry 3, '01', :file_logged_date, make_utc_date(2017, 1, 17)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 4, '01', :file_logged_date, make_utc_date(2015, 12, 13)
      ent_2018_Feb = make_entry 5, '01', :file_logged_date, make_utc_date(2018, 2, 8)

      Timecop.freeze(make_eastern_date(2017, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'file_logged_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => true, 'include_taxes' => false, 'include_other_fees' => false})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_file_logged_date_[2016_2017].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 45
      expect(sheet[4]).to eq [2016, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[6]).to eq ['Entry Summary Lines', 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet[7]).to eq ['Total Units', 1086.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1086.4]
      expect(sheet[8]).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[9]).to eq ['Total Entered Value', 111.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.1]
      expect(sheet[10]).to eq ['Total Duty', 88.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet[11]).to eq ['MPF', 66.66, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 66.66]
      expect(sheet[12]).to eq ['HMF', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet[13]).to eq ['Cotton Fee', 22.22, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 22.22]
      expect(sheet[14]).to eq ['Total Fees', 15.54, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 15.54]
      expect(sheet[15]).to eq ['Total Duty & Fees', 104.42, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 104.42]
      expect(sheet[16]).to eq ['Total Broker Invoice', 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet[17]).to eq []
      expect(sheet[18]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[19]).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[20]).to eq ['Entry Summary Lines', 2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet[21]).to eq ['Total Units', 543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet[22]).to eq ['Entry Type 01', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[23]).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 55.55]
      expect(sheet[24]).to eq ['Total Duty', 44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 44.44]
      expect(sheet[25]).to eq ['MPF', 33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 33.33]
      expect(sheet[26]).to eq ['HMF', 22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 22.22]
      expect(sheet[27]).to eq ['Cotton Fee', 11.11, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 11.11]
      expect(sheet[28]).to eq ['Total Fees', 7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 7.77]
      expect(sheet[29]).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 52.21]
      expect(sheet[30]).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet[31]).to eq []
      expect(sheet[32]).to eq ['Variance 2016 / 2017', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[33]).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[34]).to eq ['Entry Summary Lines', -2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet[35]).to eq ['Total Units', -543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet[36]).to eq ['Entry Type 01', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[37]).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet[38]).to eq ['Total Duty', -44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet[39]).to eq ['MPF', -33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet[40]).to eq ['HMF', -22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet[41]).to eq ['Cotton Fee', -11.11, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -11.11]
      expect(sheet[42]).to eq ['Total Fees', -7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet[43]).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet[44]).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]

      raw_sheet = reader["Data"]
      expect(raw_sheet.length).to eq 4
    end

    it "generates spreadsheet based on fiscal date" do
      ent_2016_Jan_1 = make_entry 1, '01', :fiscal_date, make_utc_date(2016, 1, 16)
      ent_2016_Jan_2 = make_entry 2, '01', :fiscal_date, make_utc_date(2016, 1, 17)
      ent_2017_Jan = make_entry 3, '01', :fiscal_date, make_utc_date(2017, 1, 17)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 4, '01', :fiscal_date, make_utc_date(2015, 12, 13)
      ent_2018_Feb = make_entry 5, '01', :fiscal_date, make_utc_date(2018, 2, 8)

      Timecop.freeze(make_eastern_date(2017, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'fiscal_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => true, 'include_other_fees' => false})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_fiscal_date_[2016_2017].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 45
      expect(sheet[4]).to eq [2016, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[6]).to eq ['Entry Summary Lines', 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet[7]).to eq ['Total Units', 1086.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1086.4]
      expect(sheet[8]).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[9]).to eq ['Total Entered Value', 111.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.1]
      expect(sheet[10]).to eq ['Total Duty', 88.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet[11]).to eq ['MPF', 66.66, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 66.66]
      expect(sheet[12]).to eq ['HMF', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet[13]).to eq ['Total Taxes', 19.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 19.98]
      expect(sheet[14]).to eq ['Total Fees', 15.54, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 15.54]
      expect(sheet[15]).to eq ['Total Duty & Fees', 104.42, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 104.42]
      expect(sheet[16]).to eq ['Total Broker Invoice', 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet[17]).to eq []
      expect(sheet[18]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[19]).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[20]).to eq ['Entry Summary Lines', 2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet[21]).to eq ['Total Units', 543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet[22]).to eq ['Entry Type 01', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[23]).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 55.55]
      expect(sheet[24]).to eq ['Total Duty', 44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 44.44]
      expect(sheet[25]).to eq ['MPF', 33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 33.33]
      expect(sheet[26]).to eq ['HMF', 22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 22.22]
      expect(sheet[27]).to eq ['Total Taxes', 9.99, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 9.99]
      expect(sheet[28]).to eq ['Total Fees', 7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 7.77]
      expect(sheet[29]).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 52.21]
      expect(sheet[30]).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet[31]).to eq []
      expect(sheet[32]).to eq ['Variance 2016 / 2017', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[33]).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[34]).to eq ['Entry Summary Lines', -2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet[35]).to eq ['Total Units', -543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet[36]).to eq ['Entry Type 01', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[37]).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet[38]).to eq ['Total Duty', -44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet[39]).to eq ['MPF', -33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet[40]).to eq ['HMF', -22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet[41]).to eq ['Total Taxes', -9.99, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -9.99]
      expect(sheet[42]).to eq ['Total Fees', -7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet[43]).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet[44]).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]

      raw_sheet = reader["Data"]
      expect(raw_sheet.length).to eq 4
    end

    it "generates spreadsheet based on release date" do
      ent_2016_Jan_1 = make_entry 1, '01', :release_date, make_utc_date(2016, 1, 16)
      ent_2016_Jan_2 = make_entry 2, '01', :release_date, make_utc_date(2016, 1, 17)
      ent_2017_Jan = make_entry 3, '01', :release_date, make_utc_date(2017, 1, 17)

      # These should be excluded because they are outside our date ranges.
      ent_2015_Dec = make_entry 4, '01', :release_date, make_utc_date(2015, 12, 13)
      ent_2018_Feb = make_entry 5, '01', :release_date, make_utc_date(2018, 2, 8)

      Timecop.freeze(make_eastern_date(2017, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'release_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => true})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_CRUDCO_release_date_[2016_2017].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 45
      expect(sheet[4]).to eq [2016, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[6]).to eq ['Entry Summary Lines', 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4]
      expect(sheet[7]).to eq ['Total Units', 1086.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1086.4]
      expect(sheet[8]).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[9]).to eq ['Total Entered Value', 111.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.1]
      expect(sheet[10]).to eq ['Total Duty', 88.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.88]
      expect(sheet[11]).to eq ['MPF', 66.66, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 66.66]
      expect(sheet[12]).to eq ['HMF', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet[13]).to eq ['Other Fees', 17.76, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 17.76]
      expect(sheet[14]).to eq ['Total Fees', 15.54, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 15.54]
      expect(sheet[15]).to eq ['Total Duty & Fees', 104.42, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 104.42]
      expect(sheet[16]).to eq ['Total Broker Invoice', 24.68, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24.68]
      expect(sheet[17]).to eq []
      expect(sheet[18]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[19]).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[20]).to eq ['Entry Summary Lines', 2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 2]
      expect(sheet[21]).to eq ['Total Units', 543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 543.2]
      expect(sheet[22]).to eq ['Entry Type 01', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[23]).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 55.55]
      expect(sheet[24]).to eq ['Total Duty', 44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 44.44]
      expect(sheet[25]).to eq ['MPF', 33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 33.33]
      expect(sheet[26]).to eq ['HMF', 22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 22.22]
      expect(sheet[27]).to eq ['Other Fees', 8.88, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 8.88]
      expect(sheet[28]).to eq ['Total Fees', 7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 7.77]
      expect(sheet[29]).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 52.21]
      expect(sheet[30]).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 12.34]
      expect(sheet[31]).to eq []
      expect(sheet[32]).to eq ['Variance 2016 / 2017', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[33]).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[34]).to eq ['Entry Summary Lines', -2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet[35]).to eq ['Total Units', -543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet[36]).to eq ['Entry Type 01', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[37]).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet[38]).to eq ['Total Duty', -44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet[39]).to eq ['MPF', -33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet[40]).to eq ['HMF', -22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet[41]).to eq ['Other Fees', -8.88, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -8.88]
      expect(sheet[42]).to eq ['Total Fees', -7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet[43]).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet[44]).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]

      raw_sheet = reader["Data"]
      expect(raw_sheet.length).to eq 4
    end

    it "ensures years are in chronological order" do
      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017, 1, 16)
      ent_2017_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2017, 1, 17)
      ent_2018_Jan = make_entry 3, '01', :eta_date, make_utc_date(2018, 1, 17)

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        # Report should wind up being ordered 2017 then 2018, not 2018 then 2017.
        @temp = described_class.run_report(u, {'year_1' => '2018', 'year_2' => '2017', 'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 42
      expect(sheet[4]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[17]).to eq [2018, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[18]).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[30]).to eq ['Variance 2017 / 2018', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[31]).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "defaults years when not provided" do
      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017, 1, 16)
      ent_2017_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2017, 1, 17)
      ent_2018_Jan = make_entry 3, '01', :eta_date, make_utc_date(2018, 1, 17)

      # These should be excluded because they are outside our date ranges.
      ent_2016_Dec = make_entry 3, '01', :eta_date, make_utc_date(2016, 12, 13)
      ent_2019_Feb = make_entry 4, '01', :eta_date, make_utc_date(2019, 2, 8)

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 42
      expect(sheet[4]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[17]).to eq [2018, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[18]).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[30]).to eq ['Variance 2017 / 2018', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[31]).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "appropriate handles null number values" do
      ent_2016_Jan_1 = FactoryBot(:entry, customer_number:'ABCD', customer_name:'Crudco', broker_reference:"brok ref 1",
                      entry_type:'01', arrival_date:make_utc_date(2016, 1, 16), importer_id:importer.id)
      ent_2016_Jan_2 = make_entry 2, '01', :arrival_date, make_utc_date(2016, 1, 17)
      ent_2017_Jan = FactoryBot(:entry, customer_number:'ABCD', customer_name:'Crudco', broker_reference:"brok ref 3",
                      entry_type:'01', arrival_date:make_utc_date(2017, 1, 1), importer_id:importer.id)

      Timecop.freeze(make_eastern_date(2017, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2016', 'year_2' => '2017', 'range_field' => 'arrival_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => true, 'include_taxes' => true, 'include_other_fees' => true})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 51
      expect(sheet[4]).to eq [2016, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[6]).to eq ['Entry Summary Lines', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[7]).to eq ['Total Units', 543.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 543.2]
      expect(sheet[8]).to eq ['Entry Type 01', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[9]).to eq ['Total Entered Value', 55.55, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 55.55]
      expect(sheet[10]).to eq ['Total Duty', 44.44, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 44.44]
      expect(sheet[11]).to eq ['MPF', 33.33, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 33.33]
      expect(sheet[12]).to eq ['HMF', 22.22, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 22.22]
      expect(sheet[13]).to eq ['Cotton Fee', 11.11, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 11.11]
      expect(sheet[14]).to eq ['Total Taxes', 9.99, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 9.99]
      expect(sheet[15]).to eq ['Other Fees', 8.88, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 8.88]
      expect(sheet[16]).to eq ['Total Fees', 7.77, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.77]
      expect(sheet[17]).to eq ['Total Duty & Fees', 52.21, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 52.21]
      expect(sheet[18]).to eq ['Total Broker Invoice', 12.34, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 12.34]
      expect(sheet[19]).to eq []
      expect(sheet[20]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[21]).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[22]).to eq ['Entry Summary Lines', 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[23]).to eq ['Total Units', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[24]).to eq ['Entry Type 01', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[25]).to eq ['Total Entered Value', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[26]).to eq ['Total Duty', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[27]).to eq ['MPF', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[28]).to eq ['HMF', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[29]).to eq ['Cotton Fee', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[30]).to eq ['Total Taxes', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[31]).to eq ['Other Fees', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[32]).to eq ['Total Fees', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[33]).to eq ['Total Duty & Fees', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[34]).to eq ['Total Broker Invoice', 0.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, 0.0]
      expect(sheet[35]).to eq []
      expect(sheet[36]).to eq ['Variance 2016 / 2017', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[37]).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[38]).to eq ['Entry Summary Lines', -2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -2]
      expect(sheet[39]).to eq ['Total Units', -543.2, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -543.2]
      expect(sheet[40]).to eq ['Entry Type 01', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
      expect(sheet[41]).to eq ['Total Entered Value', -55.55, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -55.55]
      expect(sheet[42]).to eq ['Total Duty', -44.44, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -44.44]
      expect(sheet[43]).to eq ['MPF', -33.33, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -33.33]
      expect(sheet[44]).to eq ['HMF', -22.22, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -22.22]
      expect(sheet[45]).to eq ['Cotton Fee', -11.11, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -11.11]
      expect(sheet[46]).to eq ['Total Taxes', -9.99, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -9.99]
      expect(sheet[47]).to eq ['Other Fees', -8.88, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -8.88]
      expect(sheet[48]).to eq ['Total Fees', -7.77, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -7.77]
      expect(sheet[49]).to eq ['Total Duty & Fees', -52.21, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -52.21]
      expect(sheet[50]).to eq ['Total Broker Invoice', -12.34, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil, nil, nil, -12.34]
    end

    it "filters by transport mode when provided" do
      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017, 1, 16), transport_mode_code:'10'
      ent_2017_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2017, 1, 17), transport_mode_code:'41'

      # This is a rail shipment, and we're looking for air and sea only, so it should be excluded.
      ent_2018_Jan = make_entry 3, '01', :eta_date, make_utc_date(2018, 1, 17), transport_mode_code:'20'

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false, 'mode_of_transport' => ['Air', 'Sea']})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 42
      expect(sheet[4]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[17]).to eq [2018, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[18]).to eq ['Number of Entries', 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[30]).to eq ['Variance 2017 / 2018', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[31]).to eq ['Number of Entries', -2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -2]
    end

    it "filters by entry type when provided" do
      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017, 1, 16)
      ent_2017_Jan_2 = make_entry 2, '02', :eta_date, make_utc_date(2017, 1, 17)

      # This is type 03, and we're looking for 01 and 02 only, so it should be excluded.
      ent_2018_Jan = make_entry 3, '03', :eta_date, make_utc_date(2018, 1, 17)

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false, 'entry_types' => ['01', '02']})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2
      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 45
      expect(sheet[4]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[18]).to eq [2018, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[19]).to eq ['Number of Entries', 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[32]).to eq ['Variance 2017 / 2018', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[33]).to eq ['Number of Entries', -2, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -2]
    end

    it "ignores transport mode and entry type params when default All Modes/blank values are selected" do
      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017, 1, 16), transport_mode_code:'10'
      ent_2017_Jan_2 = make_entry 2, '02', :eta_date, make_utc_date(2017, 1, 17), transport_mode_code:'40'
      ent_2018_Jan = make_entry 3, '03', :eta_date, make_utc_date(2018, 1, 17), transport_mode_code:'20'

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'eta_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false, 'entry_types' => '', 'mode_of_transport' => ['All Modes']})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2
      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet.length).to eq 48
      expect(sheet[4]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[19]).to eq [2018, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[20]).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[34]).to eq ['Variance 2017 / 2018', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[35]).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "handles multiple importer selection" do
      importer_2 = FactoryBot(:company, name:'Crudco Bitter Rival')

      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017, 1, 16)
      ent_2017_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2017, 1, 17)
      ent_2017_Jan_2.update_attributes :importer_id => importer_2.id
      ent_2018_Jan = make_entry 3, '01', :eta_date, make_utc_date(2018, 1, 17)
      ent_2018_Jan.update_attributes :importer_id => importer_2.id

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'eta_date', 'importer_ids' => [importer.id, importer_2.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_MULTI_eta_date_[2017_2018].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      sheet = reader["MULTI COMPANY - REPORT"]
      expect(sheet.length).to eq 42
      expect(sheet[4]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
      expect(sheet[17]).to eq [2018, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[18]).to eq ['Number of Entries', 1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 1]
      expect(sheet[30]).to eq ['Variance 2017 / 2018', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[31]).to eq ['Number of Entries', -1, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, -1]
    end

    it "sanitizes dirty input" do
      ent_2017_Jan_1 = make_entry 1, '01', :eta_date, make_utc_date(2017, 1, 16)
      ent_2017_Jan_2 = make_entry 2, '01', :eta_date, make_utc_date(2017, 1, 17)

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => "eta_date';drop table entries", 'importer_ids' => [importer.id, "555;drop table entries"], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false, 'entry_types' => ['01', '02;drop table entries'], 'mode_of_transport' => ['Air', "Sea';drop table entries"]})
      end
      expect(@temp.original_filename).to eq 'Entry_YoY_MULTI_arrival_date_[2017_2018].xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      # Nothing should match.  This test is mostly just to verify that the inject-y SQL isn't blowing up the report.
      sheet = reader["MULTI COMPANY - REPORT"]
      expect(sheet.length).to eq 39
      expect(sheet[4]).to eq [2017, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[5]).to eq ['Number of Entries', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      expect(sheet[16]).to eq [2018, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[17]).to eq ['Number of Entries', 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 0]
      expect(sheet[28]).to eq ['Variance 2017 / 2018', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December', 'Grand Totals']
      expect(sheet[29]).to eq ['Number of Entries', 0, 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 0]
    end

    it "handles UTC time value that falls into another month when converted to eastern, release" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry 1, '01', :release_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00")

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'release_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet[5]).to eq ['Number of Entries', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "handles UTC time value that falls off the report when converted to eastern, release" do
      # This should be interpreted as December 2016, and left off the report, not January 2017.
      ent_2016 = make_entry 1, '01', :release_date, ActiveSupport::TimeZone["UTC"].parse("2017-01-01 02:00")

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'release_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet[5]).to eq ['Number of Entries', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    end

    it "handles UTC time value that falls into another month when converted to eastern, arrival" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry 1, '01', :arrival_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00")

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'arrival_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet[5]).to eq ['Number of Entries', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "handles UTC time value that falls into another month when converted to eastern, file logged" do
      # This should be interpreted as January, not February.
      ent_2017 = make_entry 1, '01', :file_logged_date, ActiveSupport::TimeZone["UTC"].parse("2017-02-01 02:00")

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        @temp = described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'file_logged_date', 'importer_ids' => [importer.id], 'include_cotton_fee' => false, 'include_taxes' => false, 'include_other_fees' => false})
      end

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      sheet = reader["Crudco Consumables an - REPORT"]
      expect(sheet[5]).to eq ['Number of Entries', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "sends email if email address provided" do
      ent_2017_Jan = make_entry 1, '01', :arrival_date, make_utc_date(2017, 1, 1)

      Timecop.freeze(make_eastern_date(2018, 5, 28)) do
        described_class.run_report(u, {'year_1' => '2017', 'year_2' => '2018', 'range_field' => 'arrival_date', 'importer_ids' => [importer.id], 'email' => ['a@b.com', 'b@c.dom']})
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['a@b.com', 'b@c.dom']
      expect(mail.subject).to eq "CRUDCO YoY Report 2017 vs. 2018"
      expect(mail.body).to include "A year-over-year report is attached, comparing 2017 and 2018."
      expect(mail.attachments.count).to eq 1

      Tempfile.open('attachment') do |t|
        t.binmode
        t << mail.attachments.first.read
        t.flush
        reader = XlsxTestReader.new(t.path).raw_workbook_data
        sheet = reader["Crudco Consumables an - REPORT"]
        expect(sheet.length).to eq 42
        expect(sheet[4]).to eq [2017, "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December", "Grand Totals"]
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
