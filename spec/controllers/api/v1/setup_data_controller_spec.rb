describe Api::V1::SetupDataController do
  before :each do
    @u = Factory(:user)
    allow_api_access @u
  end
  describe "index" do
    context "countries & regions" do
      before :each do
        @us = Factory(:country, iso_code:'US', name:'United States', import_location:true, classification_rank: 1)
        @ca = Factory(:country, iso_code:'CA', name:'Canada', import_location:true)
        @cn = Factory(:country, iso_code:'CN', name:'China')
        @mx = Factory(:country, iso_code:'MX', name:'Mexico', classification_rank: 2)
      end
      it "should return all import countries" do
        expected = [
          {'id'=>@us.id, 'iso_code'=>'US', 'name'=>'United States', 'classification_rank'=>1},
          {'id'=>@ca.id, 'iso_code'=>'CA', 'name'=> 'Canada', 'classification_rank'=>nil}
        ]

        expect(get :index).to be_success
        expect(JSON.parse(response.body)['import_countries']).to eq expected
      end
      it "should provide all regions" do
        nato = Factory(:region, name:'NATO')
        nato.countries << @us
        nato.countries << @ca

        north_america = Factory(:region, name:'NorthAmerica')
        north_america.countries << @us
        north_america.countries << @ca
        north_america.countries << @mx

        expected = [
          {'id'=>nato.id, 'name'=>'NATO', 'countries'=>['US', 'CA']},
          {'id'=>north_america.id, 'name'=>'NorthAmerica', 'countries'=>['US', 'CA', 'MX']}
        ]

        expect(get :index).to be_success
        expect(JSON.parse(response.body)['regions']).to eq expected
      end
    end
  end
end