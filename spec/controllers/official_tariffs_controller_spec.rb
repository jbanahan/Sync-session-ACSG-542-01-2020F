require 'spec_helper'

describe OfficialTariffsController do
  before :each do
    @us = Factory(:country,:iso_code=>"US", import_location: true)
    @ca = Factory(:country,:iso_code=>"CA", import_location: true)
    @us_hts_1 = Factory(:official_tariff,:hts_code=>'1234567890',:country=>@us,:remaining_description=>'abc',:general_rate=>'11',:use_count=>5)
    @us_hts_2 = Factory(:official_tariff,:hts_code=>'1234567899',:country=>@us,:remaining_description=>'def',:general_rate=>'aa',:use_count=>3)
    @ca_hts = Factory(:official_tariff,:hts_code=>'1234567777',:country=>@ca,:remaining_description=>'xyz',:most_favored_nation_rate=>'123',:use_count=>6)
  end
  describe :auto_complete do
    it "should return array of tariffs for given country" do
      get :auto_complete, 'hts'=>'1234', 'country'=>@us.id.to_s, :format=>:json
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq(['1234567890','1234567899'])
    end
  end
  describe :auto_classify do
    it "should return import country classifications" do
      get :auto_classify, 'hts'=>'123456789'
      expect(response).to be_success
      body = JSON.parse response.body
      expect(body.size).to eq(2)
      x = body.first
      y = body.last
      expect(x['country_id']).to eq(@ca.id)
      expect(y['country_id']).to eq(@us.id)
      expect(x['hts']).to eq( 
          [{"lacey_act"=>false, "code"=>"1234567777", 
          "desc"=>"xyz", "rate"=>"123", "use_count"=>6}]
      )
      expect(y['hts']).to eq( 
          [{"lacey_act"=>false, "code"=>"1234567890", 
          "desc"=>"abc", "rate"=>"11", "use_count"=>5}, 
          {"lacey_act"=>false, "code"=>"1234567899", 
          "desc"=>"def", "rate"=>"aa", "use_count"=>3}]
      )
    end
  end
end
