require 'spec_helper'

describe Api::V1::OrdersController do
  before(:each) do
    MasterSetup.get.update_attributes(order_enabled:true)
    @u = Factory(:master_user,order_edit:true,order_view:true,product_view:true)
    allow_api_access @u
  end
  describe :index do
    it 'should list orders' do
      o1 = Factory(:order,order_number:'123')
      o2 = Factory(:order,order_number:'ABC')
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results'].collect{|r| r['ord_ord_num']}).to eq ['123','ABC']
    end
  end
end