require 'spec_helper'

describe OrdersController do

  before :each do 
    MasterSetup.get.update_attributes(:order_enabled=>true)
    c = Factory(:company,:master=>true)
    @u = Factory(:master_user,order_view:true,:company=>c)

    sign_in_as @u
  end

  describe :accept do
    it "should accept if user has permission" do
      Order.any_instance.should_receive(:async_accept!).with(@u)
      Order.any_instance.stub(:can_accept?).and_return true
      o = Factory(:order)
      post :accept, id: o.id
      expect(response).to redirect_to o
    end
    it "should error if user does not have permission" do
      Order.any_instance.should_not_receive(:async_accept!)
      Order.any_instance.stub(:can_accept?).and_return false
      o = Factory(:order)
      post :accept, id: o.id
    end
  end

  describe :unaccept do
    it "should unaccept if user has permission" do
      Order.any_instance.should_receive(:async_unaccept!).with(@u)
      Order.any_instance.stub(:can_accept?).and_return true
      o = Factory(:order)
      post :unaccept, id: o.id
      expect(response).to redirect_to o
    end
    it "should error if user does not have permission" do
      Order.any_instance.should_not_receive(:async_unaccept!)
      Order.any_instance.stub(:can_accept?).and_return false
      o = Factory(:order)
      post :unaccept, id: o.id
    end
  end

  describe :close do
    it "should close if user has permission" do
      Order.any_instance.stub(:can_close?).and_return true
      o = Factory(:order)
      post :close, id: o.id
      expect(response).to redirect_to o
      o.reload
      expect(o.closed_by).to eq @u
      expect(o.closed_at).to be > 1.minute.ago
    end
    it "should error if user cannot close" do
      Order.any_instance.stub(:can_close?).and_return false
      o = Factory(:order)
      post :close, id: o.id
      expect(response).to be_redirect
      o.reload
      expect(o.closed_by).to be_nil
      expect(o.closed_at).to be_nil
    end
  end
  describe :reopen do
    before :each do
      @o = Factory(:order,closed_at:Time.now)
    end
    it "should reopen if user can close" do
      Order.any_instance.stub(:can_close?).and_return true
      post :reopen, id: @o.id
      expect(response).to redirect_to @o
      @o.reload
      expect(@o.closed_at).to be_nil
    end
    it "should error if user cannot close" do
      Order.any_instance.stub(:can_close?).and_return false
      post :reopen, id: @o.id
      expect(response).to be_redirect
      @o.reload
      expect(@o.closed_at).to_not be_nil
    end
  end
  describe 'validation_results' do 
    before :each do
      @ord = Factory(:order,order_number:'123456')
      @rule_result = Factory(:business_validation_rule_result)
      @bvr = @rule_result.business_validation_result
      @bvr.state = 'Fail'
      @bvr.validatable = @ord
      @bvr.save!
    end
    it "should render page" do
      get :validation_results, id: @ord.id
      expect(response).to be_success
      expect(assigns(:order)).to eq @ord
    end
    it "should render json" do
      @bvr.business_validation_template.update_attributes(name:'myname')
      @rule_result.business_validation_rule.update_attributes(name:'rulename',description:'ruledesc')
      @rule_result.note = 'abc'
      @rule_result.state = 'Pass'
      @rule_result.overridden_by = @u
      @rule_result.overridden_at = Time.now
      @rule_result.save!
      @rule_result.reload #fixes time issue
      get :validation_results, id: @ord.id, format: :json
      expect(response).to be_success
      h = JSON.parse(response.body)['business_validation_result']
      expect(h['object_number']).to eq @ord.order_number
      expect(h['single_object']).to eq "Order"
      expect(h['state']).to eq @bvr.state
      bv_results = h['bv_results']
      expect(bv_results.length).to eq 1
      bvr = bv_results.first
      expect(bvr['id']).to eq @bvr.id
      expect(bvr['state']).to eq @bvr.state
      expect(bvr['template']['name']).to eq 'myname'
      expect(bvr['rule_results'].length).to eq 1
      rr = bvr['rule_results'].first
      expect(rr['id']).to eq @rule_result.id
      expect(rr['rule']['name']).to eq 'rulename'
      expect(rr['rule']['description']).to eq 'ruledesc'
      expect(rr['note']).to eq 'abc'
      expect(rr['overridden_by']['full_name']).to eq @u.full_name
      expect(Time.parse(rr['overridden_at'])).to eq @rule_result.overridden_at
    end
  end
end
