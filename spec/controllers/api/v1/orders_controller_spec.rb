require 'spec_helper'

describe Api::V1::OrdersController do
  before(:each) do
    MasterSetup.get.update_attributes(order_enabled:true)
    @u = Factory(:master_user,order_edit:true,order_view:true,product_view:true)
    allow_api_access @u
  end
  describe "index" do
    it 'should list orders' do
      Factory(:order,order_number:'123')
      Factory(:order,order_number:'ABC')
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results'].collect{|r| r['ord_ord_num']}).to eq ['123','ABC']
    end
    it 'should count orders' do
      Factory(:order,order_number:'123')
      Factory(:order,order_number:'ABC')
      get :index, count_only: 'true'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['record_count']).to eq 2
    end
  end
  describe "get" do
    it "should append custom_view to order if not nil" do
      allow(OpenChain::CustomHandler::CustomViewSelector).to receive(:order_view).and_return 'abc'
      o = Factory(:order)
      get :show, id: o.id
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['order']['custom_view']).to eq 'abc'
    end
    it "should append tpp_survey_response_options if not nil" do
      sr1 = double('sr1')
      allow(sr1).to receive(:id).and_return 1
      allow(sr1).to receive(:long_name).and_return 'abc'
      sr2 = double('sr2')
      allow(sr2).to receive(:id).and_return 2
      allow(sr2).to receive(:long_name).and_return 'def'
      allow_any_instance_of(Order).to receive(:available_tpp_survey_responses).and_return [sr1,sr2]

      expected = [
        {'id'=>1,'long_name'=>'abc'},
        {'id'=>2,'long_name'=>'def'}
      ]
      o = Factory(:order)
      get :show, id: o.id
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['order']['available_tpp_survey_responses']).to eq expected
    end
    it "should set permission hash" do
      o = Factory(:order)
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      allow_any_instance_of(Order).to receive(:can_edit?).and_return true
      allow_any_instance_of(Order).to receive(:can_accept?).and_return false
      allow_any_instance_of(Order).to receive(:can_be_accepted?).and_return true
      allow_any_instance_of(Order).to receive(:can_attach?).and_return true
      allow_any_instance_of(Order).to receive(:can_comment?).and_return false

      expected_permissions = {
        'can_view'=>true,
        'can_edit'=>true,
        'can_accept'=>false,
        'can_be_accepted'=>true,
        'can_attach'=>true,
        'can_comment'=>false
      }

      expect(get :show, id: o.id).to be_success

      expect(JSON.parse(response.body)['order']['permissions']).to eq expected_permissions

    end
  end

  describe "update" do
    before :each do
      @order = Factory(:order,order_number:'oldordnum')
    end
    it 'should fail if user cannot edit' do
      allow_any_instance_of(Order).to receive(:can_edit?).and_return false
      h = {'id'=>@order.id,'ord_ord_num'=>'newordnum'}
      put :update, id:@order.id, order:h
      expect(response.status).to eq 403
      @order.reload
      expect(@order.order_number).to eq 'oldordnum'
    end
    it 'should save' do
      h = {'id'=>@order.id,'ord_ord_num'=>'newordnum'}
      put :update, id:@order.id, order:h
      expect(response).to be_success
      @order.reload
      expect(@order.order_number).to eq 'newordnum'
    end
  end

  describe "accept" do
    it "should accept order if user has permission" do
      allow_any_instance_of(Order).to receive(:can_accept?).and_return true
      expect_any_instance_of(Order).to receive(:async_accept!)
      o = Factory(:order)
      post :accept, id: o.id
      expect(response).to redirect_to "/api/v1/orders/#{o.id}"
    end
    it "should fail if user does not have permission" do
      allow_any_instance_of(Order).to receive(:can_accept?).and_return false
      expect_any_instance_of(Order).not_to receive(:async_accept!)
      o = Factory(:order)
      post :accept, id: o.id
      expect(response.status).to eq 401
    end
    it "should fail if order cannot be accepted" do
      allow_any_instance_of(Order).to receive(:can_be_accepted?).and_return false
      allow_any_instance_of(Order).to receive(:can_accept?).and_return true
      expect_any_instance_of(Order).not_to receive(:async_accept!)
      o = Factory(:order)
      post :accept, id: o.id
      expect(response.status).to eq 403
    end
  end
  describe "unaccept" do
    it "should unaccept order if user has permission" do
      allow_any_instance_of(Order).to receive(:can_accept?).and_return true
      expect_any_instance_of(Order).to receive(:async_unaccept!)
      o = Factory(:order)
      post :unaccept, id: o.id
      expect(response).to redirect_to "/api/v1/orders/#{o.id}"
    end
    it "should fail if user does not have permission" do
      allow_any_instance_of(Order).to receive(:can_accept?).and_return false
      expect_any_instance_of(Order).not_to receive(:async_unaccept!)
      o = Factory(:order)
      post :unaccept, id: o.id
      expect(response.status).to eq 401
    end
  end

  describe "by_order_number" do
    it "gets order by order_number" do
      o = Factory(:order)
      get :by_order_number, order_number: o.order_number
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['order']['ord_ord_num']).to eq o.order_number.to_s
    end

    it "returns an error if order not found" do
      get :by_order_number, order_number: "NOTANORDER"
      expect(response).not_to be_success
      expect(response.status).to eq 404
    end
  end

  describe "validate" do
    it "runs validations and returns result hash" do
      MasterSetup.get.update_attributes(:order_enabled=>true)
      u = Factory(:master_user, order_view: true)
      allow_api_access u
      ord = Factory(:order)
      bvt = BusinessValidationTemplate.create!(module_type:'Order')
      bvt.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"

      post :validate, id: ord.id, :format => 'json'
      expect(bvt.business_validation_results.first.validatable).to eq ord
      expect(JSON.parse(response.body)["business_validation_result"]["single_object"]).to eq "Order"
    end
  end
end
