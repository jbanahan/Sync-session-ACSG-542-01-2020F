require 'spec_helper'

describe OfficialTariff do
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
      @us_hts = Factory(:official_tariff,:country=>@us,:hts_code=>'5555550000')
      @us_hts_2 = Factory(:official_tariff,:country=>@us,:hts_code=>'5555550001')
      @us_hts_3 = Factory(:official_tariff,:country=>@us,:hts_code=>'4444440000')
      @ca_hts = Factory(:official_tariff,:country=>@ca,:hts_code=>'5555559999')
      @ca_hts_2 = Factory(:official_tariff,:country=>@ca,:hts_code=>'5555559998')
      @de_hts = Factory(:official_tariff,:country=>@de,:hts_code=>'5555554444')
      @gb_hts = Factory(:official_tariff,:country=>@gb,:hts_code=>'5555553333') #shouldn't be returned because country isn't import location
    end
    it "should match by 6 digit for active import locations" do
      r = OfficialTariff.auto_classify "5555556666"
      r.should have(3).elements
      r[@us].collect{|h| h.hts_code}.sort.should == ['5555550000','5555550001']
      r[@ca].collect{|h| h.hts_code}.sort.should == ['5555559998','5555559999']
      r[@de].collect{|h| h.hts_code}.sort.should == ['5555554444']
    end
  end
end
