require 'spec_helper'

describe Api::V1::PortsController do
  before :each do
    @u = Factory(:user)
    allow_api_access @u
  end
  describe :autocomplete do
    it "should paginate" do
      11.times {|i| Factory(:port)}
      get :autocomplete
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 10
    end
    it "should allow name filter" do
      p = Factory(:port,name:'XabX')
      p2 = Factory(:port,name:'XdeX')
      get :autocomplete, n: 'ab'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 1
      expect(j.first['name']).to eq 'XabX'
      expect(j.first['id']).to eq p.id
    end
  end
end