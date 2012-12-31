require 'spec_helper'

describe OfficialTariffsController do
  before :each do
    @us = Factory(:country,:iso_code=>"US")
    @ca = Factory(:country,:iso_code=>"CA")
    @us_hts_1 = Factory(:official_tariff,:hts_code=>'1234567890',:country=>@us,:remaining_description=>'abc',:general_rate=>'11')
    @us_hts_2 = Factory(:official_tariff,:hts_code=>'1234567899',:country=>@us,:remaining_description=>'def',:general_rate=>'aa')
    @ca_hts = Factory(:official_tariff,:hts_code=>'1234567777',:country=>@ca,:remaining_description=>'xyz',:most_favored_nation_rate=>'123')
  end
  describe :auto_complete do
    it "should return array of tariffs for given country" do
      get :auto_complete, 'hts'=>'1234', 'country'=>@us.id.to_s, :format=>:json
      response.should be_success
      JSON.parse(response.body).should == ['1234567890','1234567899']
    end
  end
  describe :auto_classify do
    it "should return import country classifications" do
      #need to use general rate for us and mfn rate for CA to populate the common rate field when OfficialTariff is saved
      stub_hash = {@us=>[@us_hts_1,@us_hts_2],@ca=>[@ca_hts]}
      OfficialTariff.should_receive(:auto_classify).with('5555550000').and_return(stub_hash)
      get :auto_classify, 'hts'=>'5555550000'
      response.should be_success
      body = JSON.parse response.body
      body.should have(2).results
      body.each do |b|
        case b['iso']
        when 'US'
          b['country_id'].should == @us.id
          b['hts'].should == [{'code'=>'1234567890','desc'=>'abc','rate'=>'11'},{'code'=>'1234567899','desc'=>'def','rate'=>'aa'}]
        when 'CA'
          b['country_id'].should == @ca.id
          b['hts'].should == [{'code'=>'1234567777','desc'=>'xyz','rate'=>'123'}]
        else
          fail "Unexpected ISO #{b['iso']}"
        end
      end
    end
  end
end
