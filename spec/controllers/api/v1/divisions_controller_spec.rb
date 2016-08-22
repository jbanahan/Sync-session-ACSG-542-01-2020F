require 'spec_helper'

describe Api::V1::DivisionsController do
  before :each do
    @u = Factory(:user)
    allow_api_access @u
  end
  describe "autocomplete" do
    it "should autocomplete" do
      d = Division.create(name:'Div')

      expect(get :autocomplete, n: 'd').to be_success
      expect(JSON.parse(response.body)).to eq [{'val'=>'Div'}]
    end
  end
end