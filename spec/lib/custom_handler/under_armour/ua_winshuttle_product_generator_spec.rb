describe OpenChain::CustomHandler::UnderArmour::UaWinshuttleProductGenerator do

  it "should have sync_code" do
    expect(described_class.new.sync_code).to eq('winshuttle')
  end
  describe "run_and_email" do
    it "should run_and_email" do
      d = double('class')
      expect(d).to receive(:sync_xls).and_return 'xyz'
      expect(d).to receive(:email_file).with('xyz', 'j@sample.com')
      expect(ArchivedFile).to receive(:make_from_file!).with('xyz', 'Winshuttle Output', /Sent to j@sample.com at /)
      allow(described_class).to receive(:new).and_return d
      described_class.run_and_email('j@sample.com')
    end
    it "should not email if file is nil" do
      d = double('class')
      expect(d).to receive(:sync_xls).and_return nil
      expect(d).not_to receive(:email_file)
      expect(ArchivedFile).not_to receive(:make_from_file!)
      allow(described_class).to receive(:new).and_return d
      described_class.run_and_email('j@sample.com')
    end
  end
  describe "sync" do
    before :each do
      @plant_cd = described_class.prep_custom_definitions([:plant_codes])[:plant_codes]
      @colors_cd = described_class.prep_custom_definitions([:colors])[:colors]
      DataCrossReference.load_cross_references StringIO.new("0010,US\n0011,CA\n0012,CN"), DataCrossReference::UA_PLANT_TO_ISO
      @ca = create(:country, iso_code:'CA')
      @us = create(:country, iso_code:'US')
      @cn = create(:country, iso_code:'CN')
      @mx = create(:country, iso_code:'MX')
    end
    it "should elminiate items that don't need sync via query" do
      # prepping data
      p = create(:product)
      p.update_custom_value! @plant_cd, "0010\n0011"
      p.update_custom_value! @colors_cd, '001'
      allow(DataCrossReference).to receive(:find_ua_material_color_plant).and_return('1')
      create(:tariff_record, hts_1:"12345678", classification:create(:classification, country_id:@us.id, product:p))
      rows = []
      described_class.new.sync {|row| rows << row}
      expect(rows.size).to eq(2)

      # running a second time shouldn't result in any rows from query to be processed
      rows = []
      g = described_class.new
      expect(g).not_to receive(:preprocess_row)
      g.sync {|r| rows << r}
      expect(rows).to be_empty
    end
    it "should match plant to country" do
      p = create(:product)
      p.update_custom_value! @plant_cd, "0010\n0011"
      p.update_custom_value! @colors_cd, '001'
      allow(DataCrossReference).to receive(:find_ua_material_color_plant).and_return('1')
      [@ca, @us, @cn, @mx].each do |c|
        # create a classification with tariff for all countries
        create(:tariff_record, hts_1:"#{c.id}12345678", classification:create(:classification, country_id:c.id, product:p))
      end
      rows = []
      described_class.new.sync {|row| rows << row}
      expect(rows.size).to eq(3)
      [rows[1], rows[2]].each do |r|
        expect(r[0]).to be_blank
        expect(r[1]).to eq("#{p.unique_identifier}-001")
        expect(['0010', '0011'].include?(r[2])).to be_truthy
        expect(r[3]).to eq("#{r[2]=='0010' ? @us.id: @ca.id}12345678".hts_format)
      end
    end
    it "should write color codes that are in the xref" do
      p = create(:product)
      p.update_custom_value! @plant_cd, "0010\n0011"
      p.update_custom_value! @colors_cd, "001\n002"
      DataCrossReference.create_ua_material_color_plant! p.unique_identifier, '001', '0010'
      DataCrossReference.create_ua_material_color_plant! p.unique_identifier, '002', '0011'
      [@ca, @us].each do |c|
        # create a classification with tariff for relevant countries
        create(:tariff_record, hts_1:"#{c.id}12345678", classification:create(:classification, country_id:c.id, product:p))
      end
      rows = []
      described_class.new.sync {|row| rows << row}
      expect(rows.size).to eq(3)
      [rows[1], rows[2]].each do |r|
        expect(r.size).to eq(4)
        expect(r[0]).to be_blank
        expect(r[1]).to eq("#{p.unique_identifier}-#{r[2]=='0010' ? '001' : '002'}")
        expect(['0010', '0011'].include?(r[2])).to be_truthy
        expect(r[3]).to eq("#{r[2]=='0010' ? @us.id: @ca.id}12345678".hts_format)
      end
    end
    it "should write headers" do
      p = create(:product)
      p.update_custom_value! @plant_cd, "0010"
      p.update_custom_value! @colors_cd, '001'
      allow(DataCrossReference).to receive(:find_ua_material_color_plant).and_return('1')
      create(:tariff_record, hts_1:"12345678", classification:create(:classification, country_id:@us.id, product:p))
      rows = []
      described_class.new.sync {|row| rows << row}
      r = rows.first
      expect(r[0]).to match /Log Winshuttle RUNNER for TRANSACTION 10\.2\nMM02-Change HTS Code\.TxR\n.*\nMode:  Batch\nPRD-100, pmckeldin/
      expect(r[1]).to eq('Material Number')
      expect(r[2]).to eq('Plant')
      expect(r[3]).to eq('HTS Code')
    end
    it "should only send changed tariff codes since the last send" do
      p = create(:product)
      p.update_custom_value! @plant_cd, "0010\n0011"
      p.update_custom_value! @colors_cd, '001'
      allow(DataCrossReference).to receive(:find_ua_material_color_plant).and_return('1')
      [@ca, @us].each do |c|
        # create a classification with tariff for all countries
        create(:tariff_record, hts_1:"#{c.id}12345678", classification:create(:classification, country_id:c.id, product:p))
      end
      rows = []
      described_class.new.sync {|row| rows << row}
      expect(rows.size).to eq(3)
      p.update_attributes(updated_at:2.minutes.from_now)
      p.reload
      p.classifications.find_by(country: @ca).tariff_records.first.update_attributes(hts_1:'987654321')
      rows = []
      described_class.new.sync {|row| rows << row}
      expect(rows.size).to eq(2)
      r = rows.last
      expect(r[0]).to be_blank
      expect(r[1]).to eq("#{p.unique_identifier}-001")
      expect(r[2]).to eq('0011')
      expect(r[3]).to eq('987654321'.hts_format)
    end

    it "does not send specific material / color / plant code data that is unchanged" do
      p = create(:product)
      p.update_custom_value! @plant_cd, "0010\n0011"
      p.update_custom_value! @colors_cd, '001'
      allow(DataCrossReference).to receive(:find_ua_material_color_plant).and_return('1')
      [@ca, @us].each do |c|
        # create a classification with tariff for all countries
        create(:tariff_record, hts_1:"#{c.id}12345678", classification:create(:classification, country_id:c.id, product:p))
      end

      DataCrossReference.create_ua_winshuttle_fingerprint! p.unique_identifier, '001', '0010', Digest::MD5.hexdigest("~#{p.unique_identifier}-001~0010~#{p.classifications[1].tariff_records.first.hts_1.hts_format}")

      rows = []
      described_class.new.sync {|row| rows << row}
      expect(rows.size).to eq 2
      expect(rows[1]).to eq({0 => "", 1=> "#{p.unique_identifier}-001", 2=> "0011", 3=>p.classifications.first.tariff_records.first.hts_1.hts_format})
    end
  end

  describe "email_file" do
    before :each do
      @f = double('file')
      @mailer = double(:mailer)
      expect(@mailer).to receive(:deliver_now)
    end
    it "should email result" do
      expect(OpenMailer).to receive(:send_simple_html).with('joe@sample.com', 'Winshuttle Product Output File', 'Your Winshuttle product output file is attached.  For assistance, please email support@vandegriftinc.com', [@f]).and_return(@mailer)
      described_class.new.email_file @f, 'joe@sample.com'
    end
    it 'should make original_filename method on file object' do
      allow(OpenMailer).to receive(:send_simple_html).and_return(@mailer)
      described_class.new.email_file @f, 'joe@sample.com'
      expect(@f.original_filename).to match /winshuttle_[[:digit:]]{8}\.xls/
    end
  end
end
