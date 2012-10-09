require 'spec_helper'

describe OfficialTariff do
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
