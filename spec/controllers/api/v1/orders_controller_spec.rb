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
  describe :get do
    it "should append custom_view to order if not nil" do
      OpenChain::CustomHandler::CustomViewSelector.stub(:order_view).and_return 'abc'
      o = Factory(:order)
      get :show, id: o.id
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['order']['custom_view']).to eq 'abc'
    end
    it "should set permission hash" do
      o = Factory(:order)
      Order.any_instance.stub(:can_view?).and_return true
      Order.any_instance.stub(:can_edit?).and_return true
      Order.any_instance.stub(:can_accept?).and_return false
      Order.any_instance.stub(:can_attach?).and_return true
      Order.any_instance.stub(:can_comment?).and_return false

      expected_permissions = {
        'can_view'=>true,
        'can_edit'=>true,
        'can_accept'=>false,
        'can_attach'=>true,
        'can_comment'=>false
      }

      expect(get :show, id: o.id).to be_success

      expect(JSON.parse(response.body)['order']['permissions']).to eq expected_permissions

    end
  end
  describe :accept do
    it "should accept order if user has permission" do
      Order.any_instance.stub(:can_accept?).and_return true
      Order.any_instance.should_receive(:async_accept!)
      o = Factory(:order)
      post :accept, id: o.id
      expect(response).to redirect_to "/api/v1/orders/#{o.id}"
    end
    it "should fail if user does not have permission" do
      Order.any_instance.stub(:can_accept?).and_return false
      Order.any_instance.should_not_receive(:async_accept!)
      o = Factory(:order)
      post :accept, id: o.id
      expect(response.status).to eq 401
    end
  end
  describe :accept do
    it "should unaccept order if user has permission" do
      Order.any_instance.stub(:can_accept?).and_return true
      Order.any_instance.should_receive(:async_unaccept!)
      o = Factory(:order)
      post :unaccept, id: o.id
      expect(response).to redirect_to "/api/v1/orders/#{o.id}"
    end
    it "should fail if user does not have permission" do
      Order.any_instance.stub(:can_accept?).and_return false
      Order.any_instance.should_not_receive(:async_unaccept!)
      o = Factory(:order)
      post :unaccept, id: o.id
      expect(response.status).to eq 401
    end
  end
end