describe OpenChain::Report::PumaDivisionQuarterBreakdown do

  describe "permission?" do
    let (:u) { FactoryBot(:user) }
    let (:group) { Group.use_system_group 'puma_division_quarter_breakdown', create: true }

    it "allows access for users in group" do
      expect(u).to receive(:in_group?).with(group).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "prevents access by users who are not in the group" do
      expect(u).to receive(:in_group?).with(group).and_return false
      expect(described_class.permission? u).to eq false
    end
  end

  describe "run_report" do
    let (:u) { FactoryBot(:user) }
    let(:importer_cgolf) { with_customs_management_id(FactoryBot(:company, name:'CGOLF'), "CGOLF") }
    let(:importer_puma_us) { with_customs_management_id(FactoryBot(:company, name:'Puma USA'), "PUMA") }
    let(:importer_puma_ca) { with_fenix_id(FactoryBot(:company, name:'Puma Canada'), "892892654RM0001") }

    after { @temp.close if @temp }

    def make_entry importer, release_date, counter
      FactoryBot(:entry, importer_id:importer.id, release_date:release_date, entered_value:(123.45+counter),
              total_invoiced_value:(234.56+counter), total_duty:(45.67+counter), cotton_fee:(56.78+counter),
              hmf:(67.89+counter), mpf:(78.90+counter), total_gst:(89.01+counter))
    end

    it "generates spreadsheet" do
      ent_puma_us_2016_Feb_1 = make_entry importer_puma_us, make_utc_date(2016, 2, 16), 1
      ent_puma_us_2016_Feb_2 = make_entry importer_puma_us, make_utc_date(2016, 2, 17), 2
      ent_cgolf_2016_Mar = make_entry importer_cgolf, make_utc_date(2016, 3, 3), 3
      ent_cgolf_2016_Apr_1 = make_entry importer_cgolf, make_utc_date(2016, 4, 4), 4
      ent_cgolf_2016_Apr_2 = make_entry importer_cgolf, make_utc_date(2016, 4, 16), 5
      ent_puma_ca_2016_Apr = make_entry importer_puma_ca, make_utc_date(2016, 4, 25), 6
      ent_puma_us_2016_May = make_entry importer_puma_us, make_utc_date(2016, 5, 15), 7
      ent_puma_ca_2016_Jun = make_entry importer_puma_ca, make_utc_date(2016, 6, 6), 8
      ent_puma_us_2016_Aug_1 = make_entry importer_puma_us, make_utc_date(2016, 8, 16), 9
      ent_puma_us_2016_Aug_2 = make_entry importer_puma_us, make_utc_date(2016, 8, 17), 10
      ent_cgolf_2016_Sep = make_entry importer_cgolf, make_utc_date(2016, 9, 3), 11
      ent_cgolf_2016_Oct_1 = make_entry importer_cgolf, make_utc_date(2016, 10, 4), 12
      ent_cgolf_2016_Oct_2 = make_entry importer_cgolf, make_utc_date(2016, 10, 16), 13
      ent_puma_ca_2016_Oct = make_entry importer_puma_ca, make_utc_date(2016, 10, 25), 14
      ent_puma_ca_2016_Dec = make_entry importer_puma_ca, make_utc_date(2016, 12, 6), 16

      # Outside the date range.  Should be ignored.
      ent_2017_Jan = make_entry importer_puma_us, make_utc_date(2017, 1, 1), 17
      ent_2015_Dec = make_entry importer_puma_us, make_utc_date(2015, 12, 13), 18

      # Belongs to another importer.  Should be ignored.
      importer_not_puma = FactoryBot(:company, name:'Crudco Bitter Rival')
      ent_not_puma_2016_Feb = make_entry importer_not_puma, make_utc_date(2016, 2, 11), 19

      @temp = described_class.run_report(u, {'year' => '2016'})
      expect(@temp.original_filename).to eq 'Puma_Division_Quarter_Breakdown_2016.xlsx'

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 1

      sheet = reader["2016 Breakdown"]
      expect(sheet).to_not be_nil
      expect(sheet.length).to eq 23
      expect(sheet[0]).to eq ["CGOLF"]
      expect(sheet[1]).to eq ["", "Total Entered Value", "Total Invoice Value", "Total Duty", "Cotton Fee", "HMF", "MPF", "Entry Count"]
      expect(sheet[2]).to eq ["Qtr 1", 126.45, 237.56, 48.67, 59.78, 70.89, 81.9, 1]
      expect(sheet[3]).to eq ["Qtr 2", 255.9, 478.12, 100.34, 122.56, 144.78, 166.8, 2]
      expect(sheet[4]).to eq ["Qtr 3", 134.45, 245.56, 56.67, 67.78, 78.89, 89.9, 1]
      expect(sheet[5]).to eq ["Qtr 4", 271.9, 494.12, 116.34, 138.56, 160.78, 182.8, 2]
      expect(sheet[6]).to eq ["Grand Totals:", 788.7, 1455.36, 322.02, 388.68, 455.34, 521.4, 6]
      expect(sheet[7]).to eq []
      expect(sheet[8]).to eq ["PUMA USA"]
      expect(sheet[9]).to eq ["", "Total Entered Value", "Total Invoice Value", "Total Duty", "Cotton Fee", "HMF", "MPF", "Entry Count"]
      expect(sheet[10]).to eq ["Qtr 1", 249.9, 472.12, 94.34, 116.56, 138.78, 160.8, 2]
      expect(sheet[11]).to eq ["Qtr 2", 130.45, 241.56, 52.67, 63.78, 74.89, 85.9, 1]
      expect(sheet[12]).to eq ["Qtr 3", 265.9, 488.12, 110.34, 132.56, 154.78, 176.8, 2]
      expect(sheet[13]).to eq ["Qtr 4", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0]
      expect(sheet[14]).to eq ["Grand Totals:", 646.25, 1201.8, 257.35, 312.9, 368.45, 423.5, 5]
      expect(sheet[15]).to eq []
      expect(sheet[16]).to eq ["PUMA CA"]
      expect(sheet[17]).to eq ["", "Total Entered Value", "Total Invoice Value", "Total Duty", "Total GST", "Entry Count"]
      expect(sheet[18]).to eq ["Qtr 1", 0.0, 0.0, 0.0, 0.0, 0]
      expect(sheet[19]).to eq ["Qtr 2", 260.9, 483.12, 105.34, 192.02, 2]
      expect(sheet[20]).to eq ["Qtr 3", 0.0, 0.0, 0.0, 0.0, 0]
      expect(sheet[21]).to eq ["Qtr 4", 276.9, 499.12, 121.34, 208.02, 2]
      expect(sheet[22]).to eq ["Grand Totals:", 537.8, 982.24, 226.68, 400.04, 4]
    end

    def make_utc_date year, month, day
      ActiveSupport::TimeZone["UTC"].parse("#{year}-#{month}-#{day} 16:00")
    end
  end

end