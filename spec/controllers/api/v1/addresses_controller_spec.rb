require 'spec_helper'

describe Api::V1::AddressesController do

  describe '#index' do
    it 'should get addresses that user can view' do
      c = Factory(:company)
      Factory(:address,system_code:'ABCD',company:c)
      Factory(:address) # don't find this one

      allow_api_access Factory(:user,company:c)

      get :index
      expect(response).to be_success
      h = JSON.parse(response.body)
      expect(h['results']).to have(1).result
      expect(h['results'][0]['add_syscode']).to eq 'ABCD'
    end
    it 'should apply filters' do
      c = Factory(:company)
      Factory(:address,system_code:'ABCD',company:c)
      Factory(:address,system_code:'DEFG',company:c)
      Factory(:address) # don't find this one

      allow_api_access Factory(:user,company:c)

      get :index, sid1:'add_syscode', sop1: 'eq', sv1:'ABCD'
      expect(response).to be_success
      h = JSON.parse(response.body)
      expect(h['results']).to have(1).result
      expect(h['results'][0]['add_syscode']).to eq 'ABCD'
    end
  end

end
