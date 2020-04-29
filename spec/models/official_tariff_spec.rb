describe OfficialTariff do
  context 'callbacks' do
    it 'should set common_rate_decimal on save if numeric' do
      c = Factory(:country)
      t = OfficialTariff.create!(country_id:c.id, hts_code:'1234567890', general_rate:' 3.2% ')
      expect(t.common_rate_decimal).to eq BigDecimal('0.032')
    end
    it 'should not set common_rate_decimal on save if not numeric' do
      c = Factory(:country)
      t = OfficialTariff.create!(country_id:c.id, hts_code:'1234567890', general_rate:'10.2% plus 93.1 EUR per 100 KILOGRAMS')
      expect(t.common_rate_decimal).to be_nil
    end
    it 'should set common_rate_decimal to 0 for Free' do
      c = Factory(:country)
      t = OfficialTariff.create!(country_id:c.id, hts_code:'1234567890', general_rate:'Free')
      expect(t.common_rate_decimal).to eq 0
    end
    it 'should set special_rate_key on save' do
      special_rates = 'ABC12345'
      t = Factory(:official_tariff, special_rates:special_rates)
      expect(t.special_rate_key).to eq Digest::MD5.hexdigest(special_rates)
    end
  end
  describe "lacey_act" do
    it "should return false if the country's ISO code is not US" do
      c = Factory(:country, iso_code: "VN")
      t = Factory(:official_tariff, country: c)
      expect(t.lacey_act?).to eq(false)
    end
    it "should return true if the tariff's HTS code starts with any of the Lacey Act codes" do
      sample_lacey_codes = ["4401", "4402", "4403", "4404", "940169", "950420", "9703"]
      c = Factory(:country, iso_code: "US")
      sample_lacey_codes.each do |sample|
        t = Factory(:official_tariff, hts_code: sample + "55555", country: c)
        expect(t.lacey_act?).to eq(true)
      end
    end
    it "should return false if the country's ISO is US but the HTS code doesn't match any Lacey Act Codes" do
      c = Factory(:country, iso_code: "US")
      t = Factory(:official_tariff, hts_code: "4405155555", country: c)
      expect(t.lacey_act?).to eq(false)
    end
  end
  describe "taric_url" do
    it "should return nil if country is nil" do
      t = Factory(:official_tariff, hts_code: "ABCD")

      expect(t.taric_url).to be nil
    end

    it "should return nil if country is not in the EU" do
      c = Factory(:country)
      t = Factory(:official_tariff, country: c, hts_code: "ABCD")
      allow(c).to receive(:european_union?).and_return false

      expect(t.taric_url).to be nil
    end

    it "should return a url if country is in the EU" do
      c = Factory(:country)
      t = Factory(:official_tariff, country: c, hts_code: "ABCD")
      allow(c).to receive(:european_union?).and_return true

      expect(t.taric_url).to eq "http://ec.europa.eu/taxation_customs/dds2/taric/measures.jsp?Taric=ABCD&LangDescr=en"
    end
  end

  describe "update_use_count" do
    before :each do
      allow(OpenChain::StatClient).to receive(:wall_time).and_yield
    end
    it "should update with counts from all 3 hts code locations for the right country" do
      c = Factory(:country)
      Factory(:tariff_record, :hts_1=>'123456', :hts_2=>'123456', :hts_3=>'1111111',
        :classification=>Factory(:classification, :country=>c)
        )
      Factory(:tariff_record, :hts_1=>'123456', :hts_2=>'123456', :hts_3=>'123456',
        :classification=>Factory(:classification, :country=>c)
        )
      Factory(:tariff_record, :hts_1=>'123456', :hts_2=>'123456', :hts_3=>'123456',
        :classification=>Factory(:classification, :country=>Factory(:country)) # don't match this
        )
      ot1 = Factory(:official_tariff, :hts_code=>'123456', :country=>c)
      ot2 = Factory(:official_tariff, :hts_code=>'1111111', :country=>c)
      ot3 = Factory(:official_tariff, :hts_code=>'1111117', :country=>c)
      OfficialTariff.update_use_count
      [ot1, ot2, ot3].each {|o| o.reload}
      expect(ot1.use_count).to eq(5)
      expect(ot2.use_count).to eq(1)
      expect(ot3.use_count).to eq(0)
    end
    it "should clear use count for unused tariff" do
      ot = Factory(:official_tariff, hts_code:'21345', use_count:10, updated_at:1.day.ago)
      # we need to have a classificaiton against the country
      Factory(:tariff_record, :hts_1=>'9999999',
        :classification=>Factory(:classification, :country=>ot.country)
        )
      OfficialTariff.update_use_count
      ot.reload
      expect(ot.use_count).to eq(0)
    end
  end
  describe "can_view?" do
    it "should allow if user can view official tariffs" do
      u = User.new
      expect(u).to receive(:view_official_tariffs?).and_return(true)
      expect(OfficialTariff.new.can_view?(u)).to be_truthy
    end
    it "should not allow if user cannot view offical tariffs" do
      u = User.new
      expect(u).to receive(:view_official_tariffs?).and_return(false)
      expect(OfficialTariff.new.can_view?(u)).to be_falsey
    end
  end
  describe "search_where" do
    it "should return '1=0' if user cannot view official tariffs" do
      u = User.new
      expect(u).to receive(:view_official_tariffs?).and_return(false)
      expect(OfficialTariff.search_where(u)).to eq('1=0')
    end
    it "should return '1=1' if user can view official tariffs" do
      u = User.new
      expect(u).to receive(:view_official_tariffs?).and_return(true)
      expect(OfficialTariff.search_where(u)).to eq('1=1')
    end
  end
  describe "search_secure" do
    it "should inject search where" do
      u = User.new
      expect(OfficialTariff).to receive(:search_where).with(u).and_return('XX')
      expect(OfficialTariff.search_secure(u, OfficialTariff).to_sql).to include 'XX'
    end
  end
  describe "auto_classify" do
    before :each do
      @us = Factory(:country, :iso_code=>'US', :import_location=>true)
      @ca = Factory(:country, :iso_code=>'CA', :import_location=>true)
      @de = Factory(:country, :iso_code=>'DE', :import_location=>true)
      @gb = Factory(:country, :iso_code=>'GB', :import_location=>false)
      @us_hts_2 = Factory(:official_tariff, :country=>@us, :hts_code=>'5555550001', :use_count=>300)
      @us_hts = Factory(:official_tariff, :country=>@us, :hts_code=>'5555550000', :use_count=>10)
      @us_hts_3 = Factory(:official_tariff, :country=>@us, :hts_code=>'4444440000', :use_count=>20)
      @ca_hts = Factory(:official_tariff, :country=>@ca, :hts_code=>'5555559999', :use_count=>4)
      @ca_hts_2 = Factory(:official_tariff, :country=>@ca, :hts_code=>'5555559998', :use_count=>7)
      @de_hts = Factory(:official_tariff, :country=>@de, :hts_code=>'5555554444', :use_count=>2)
      @gb_hts = Factory(:official_tariff, :country=>@gb, :hts_code=>'5555553333', :use_count=>5) # shouldn't be returned because country isn't import location
    end
    it "should match by 6 digit for active import locations" do
      r = OfficialTariff.auto_classify "5555556666"
      expect(r.size).to eq(3)
      expect(r[@us].collect {|h| h.hts_code}).to eq(['5555550001', '5555550000'])
      expect(r[@ca].collect {|h| h.hts_code}).to eq(['5555559998', '5555559999'])
      expect(r[@de].collect {|h| h.hts_code}).to eq(['5555554444'])
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      expect(OfficialTariff).to receive(:update_use_count)
      OfficialTariff.run_schedulable
    end
  end

  describe "valid_hts?" do
    let (:country) { Factory(:country) }
    let (:official_tariff) { OfficialTariff.create! country_id: country.id, hts_code: "1234567890" }

    it "returns true if given country + hts is valid" do
      official_tariff

      expect(OfficialTariff.valid_hts? country, "1234567890").to be_truthy
    end

    it "returns false if hts is not present" do
      expect(OfficialTariff.valid_hts? country, "1234567890").to be_falsey
    end

    it "accepts country id " do
      official_tariff

      expect(OfficialTariff.valid_hts? country.id, "1234567890").to be_truthy
    end
  end

  describe "numeric_rate_value" do
    subject { described_class }

    it "extracts numeric percentage rate from text description" do
      expect(subject.numeric_rate_value("This HTS rate contains two percentage values: 10.5% and 25%")).to eq BigDecimal("10.5")
      expect(subject.numeric_rate_value("This HTS rate contains two percentage values: 10.5% and 25%", express_as_decimal:true)).to eq BigDecimal(".105")
      expect(subject.numeric_rate_value("contains no decimals")).to be_nil
      expect(subject.numeric_rate_value("contains no decimals", express_as_decimal:true)).to be_nil
      expect(subject.numeric_rate_value(nil)).to be_nil
    end

    it "returns Free rates as 0" do
      expect(subject.numeric_rate_value "free").to eq BigDecimal('0')
    end
  end

end
