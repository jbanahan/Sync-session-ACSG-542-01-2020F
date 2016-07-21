require 'spec_helper'

describe OfficialTariff do
  context 'callbacks' do
    it 'should set common_rate_decimal on save if numeric' do
      c = Factory(:country)
      t = OfficialTariff.create!(country_id:c.id,hts_code:'1234567890',general_rate:' 3.2% ')
      expect(t.common_rate_decimal).to eq BigDecimal('0.032')
    end
    it 'should not set common_rate_decimal on save if not numeric' do
      c = Factory(:country)
      t = OfficialTariff.create!(country_id:c.id,hts_code:'1234567890',general_rate:'10.2% plus 93.1 EUR per 100 KILOGRAMS')
      expect(t.common_rate_decimal).to be_nil
    end
    it 'should set common_rate_decimal to 0 for Free' do
      c = Factory(:country)
      t = OfficialTariff.create!(country_id:c.id,hts_code:'1234567890',general_rate:'Free')
      expect(t.common_rate_decimal).to eq 0
    end
    it 'should set special_rate_key on save' do
      special_rates = 'ABC12345'
      t = Factory(:official_tariff,special_rates:special_rates)
      expect(t.special_rate_key).to eq Digest::MD5.hexdigest(special_rates)
    end
  end
  describe :lacey_act do
    it "should return false if the country's ISO code is not US" do
      c = Factory(:country, iso_code: "VN")
      t = Factory(:official_tariff, country: c)
      t.lacey_act?.should == false
    end
    it "should return true if the tariff's HTS code starts with any of the Lacey Act codes" do
      sample_lacey_codes = ["4401","4402","4403","4404","940169", "950420", "9703"]
      c = Factory(:country, iso_code: "US")
      sample_lacey_codes.each do |sample|
        t = Factory(:official_tariff, hts_code: sample + "55555", country: c)
        t.lacey_act?.should == true
      end
    end
    it "should return false if the country's ISO is US but the HTS code doesn't match any Lacey Act Codes" do
      c = Factory(:country, iso_code: "US")
      t = Factory(:official_tariff, hts_code: "4405155555", country: c)
      t.lacey_act?.should == false
    end
  end
  describe :taric_url do
    it "should return nil if country is nil" do
      t = Factory(:official_tariff, hts_code: "ABCD")

      expect(t.taric_url).to be nil
    end

    it "should return nil if country is not in the EU" do
      c = Factory(:country)
      t = Factory(:official_tariff, country: c, hts_code: "ABCD")
      c.stub(:european_union?).and_return false

      expect(t.taric_url).to be nil
    end

    it "should return a url if country is in the EU" do
      c = Factory(:country)
      t = Factory(:official_tariff, country: c, hts_code: "ABCD")
      c.stub(:european_union?).and_return true

      expect(t.taric_url).to eq "http://ec.europa.eu/taxation_customs/dds2/taric/measures.jsp?Taric=ABCD&LangDescr=en"
    end
  end

  describe :update_use_count do
    before :each do
      OpenChain::StatClient.stub(:wall_time).and_yield
    end
    it "should update with counts from all 3 hts code locations for the right country" do
      c = Factory(:country)
      Factory(:tariff_record,:hts_1=>'123456',:hts_2=>'123456',:hts_3=>'1111111',
        :classification=>Factory(:classification,:country=>c)
        )
      Factory(:tariff_record,:hts_1=>'123456',:hts_2=>'123456',:hts_3=>'123456',
        :classification=>Factory(:classification,:country=>c)
        )
      Factory(:tariff_record,:hts_1=>'123456',:hts_2=>'123456',:hts_3=>'123456',
        :classification=>Factory(:classification,:country=>Factory(:country)) #don't match this
        )
      ot1 = Factory(:official_tariff,:hts_code=>'123456',:country=>c)
      ot2 = Factory(:official_tariff,:hts_code=>'1111111',:country=>c)
      ot3 = Factory(:official_tariff,:hts_code=>'1111117',:country=>c)
      OfficialTariff.update_use_count
      [ot1,ot2,ot3].each {|o| o.reload}
      ot1.use_count.should == 5
      ot2.use_count.should == 1
      ot3.use_count.should == 0
    end
    it "should clear use count for unused tariff" do
      ot = Factory(:official_tariff,hts_code:'21345',use_count:10,updated_at:1.day.ago)
      # we need to have a classificaiton against the country
      Factory(:tariff_record,:hts_1=>'9999999',
        :classification=>Factory(:classification,:country=>ot.country)
        )
      OfficialTariff.update_use_count
      ot.reload
      ot.use_count.should == 0
    end
  end
  describe :can_view? do
    it "should allow if user can view official tariffs" do
      u = User.new
      u.should_receive(:view_official_tariffs?).and_return(true)
      OfficialTariff.new.can_view?(u).should be_true
    end
    it "should not allow if user cannot view offical tariffs" do
      u = User.new
      u.should_receive(:view_official_tariffs?).and_return(false)
      OfficialTariff.new.can_view?(u).should be_false
    end
  end
  describe :search_where do
    it "should return '1=0' if user cannot view official tariffs" do
      u = User.new
      u.should_receive(:view_official_tariffs?).and_return(false)
      OfficialTariff.search_where(u).should == '1=0'
    end
    it "should return '1=1' if user can view official tariffs" do
      u = User.new
      u.should_receive(:view_official_tariffs?).and_return(true)
      OfficialTariff.search_where(u).should == '1=1'
    end
  end
  describe :search_secure do
    it "should inject search where" do
      u = User.new
      OfficialTariff.should_receive(:search_where).with(u).and_return('XX')
      OfficialTariff.search_secure(u,OfficialTariff).to_sql.should include 'XX'
    end
  end
  describe :auto_classify do
    before :each do
      @us = Factory(:country,:iso_code=>'US',:import_location=>true)
      @ca = Factory(:country,:iso_code=>'CA',:import_location=>true)
      @de = Factory(:country,:iso_code=>'DE',:import_location=>true)
      @gb = Factory(:country,:iso_code=>'GB',:import_location=>false)
      @us_hts_2 = Factory(:official_tariff,:country=>@us,:hts_code=>'5555550001',:use_count=>300)
      @us_hts = Factory(:official_tariff,:country=>@us,:hts_code=>'5555550000',:use_count=>10)
      @us_hts_3 = Factory(:official_tariff,:country=>@us,:hts_code=>'4444440000',:use_count=>20)
      @ca_hts = Factory(:official_tariff,:country=>@ca,:hts_code=>'5555559999',:use_count=>4)
      @ca_hts_2 = Factory(:official_tariff,:country=>@ca,:hts_code=>'5555559998',:use_count=>7)
      @de_hts = Factory(:official_tariff,:country=>@de,:hts_code=>'5555554444',:use_count=>2)
      @gb_hts = Factory(:official_tariff,:country=>@gb,:hts_code=>'5555553333',:use_count=>5) #shouldn't be returned because country isn't import location
    end
    it "should match by 6 digit for active import locations" do
      r = OfficialTariff.auto_classify "5555556666"
      r.should have(3).elements
      r[@us].collect{|h| h.hts_code}.should == ['5555550001','5555550000']
      r[@ca].collect{|h| h.hts_code}.should == ['5555559998','5555559999']
      r[@de].collect{|h| h.hts_code}.should == ['5555554444']
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      OfficialTariff.should_receive(:update_use_count)
      OfficialTariff.run_schedulable
    end
  end

  describe "valid_hts?" do
    let (:country) { Factory(:country) }
    let (:official_tariff) { OfficialTariff.create! country_id: country.id, hts_code: "1234567890" }

    it "returns true if given country + hts is valid" do
      official_tariff

      expect(OfficialTariff.valid_hts? country, "1234567890").to be_true
    end

    it "returns false if hts is not present" do
      expect(OfficialTariff.valid_hts? country, "1234567890").to be_false
    end

    it "accepts country id " do
      official_tariff

      expect(OfficialTariff.valid_hts? country.id, "1234567890").to be_true
    end
  end
end
