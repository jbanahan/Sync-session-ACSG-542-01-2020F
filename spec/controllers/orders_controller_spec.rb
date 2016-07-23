require 'spec_helper'

describe OrdersController do

  before :each do
    MasterSetup.get.update_attributes(:order_enabled=>true)
    c = Factory(:company,:master=>true,system_code:'MSTR')
    @u = Factory(:master_user,order_view:true,:company=>c)

    sign_in_as @u
  end

  describe '#show' do
    context 'order_view_template' do
      it 'should render default template' do
        o = Factory(:order,importer:@u.company)
        get :show, id: o.id
        expect(response).to render_template :show
      end
      it 'should render custom template' do
        cvt = CustomViewTemplate.create!(template_identifier:'order_view',template_path:'custom_views/j_jill/orders/show', module_type: "Order")
        cvt.search_criterions.create!(model_field_uid:'ord_imp_syscode',operator:'eq',value:@u.company.system_code)
        o = Factory(:order,importer:@u.company)
        get :show, id: o.id
        expect(response).to render_template 'custom_views/j_jill/orders/show'
      end
    end
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
    it "should error if order cannot be accepted" do
      Order.any_instance.should_not_receive(:async_accept!)
      Order.any_instance.stub(:can_accept?).and_return true
      Order.any_instance.stub(:can_be_accepted?).and_return false
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
      expect(assigns(:validation_object)).to eq @ord
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
  describe 'bulk_update_fields' do
    it "returns list of model fields for user to edit" do
      post :bulk_update_fields 
      expect(JSON.parse(response.body)["mf_hsh"]).to include({"ord_ord_date" => "Order Date"})
    end
    it "skips model fields that user isn't authorized to edit" do
      ModelField.any_instance.stub(:can_edit?).and_return false
      post :bulk_update_fields 
      expect(JSON.parse(response.body)["mf_hsh"]).to be_empty
    end
    it 'should get count for specific items from #get_bulk_count' do
      described_class.any_instance.should_receive(:get_bulk_count).with({"0"=>"99","1"=>"54"}, nil).and_return 2
      post :bulk_update_fields, {"pk" => {"0"=>"99","1"=>"54"}}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 2
    end
    it 'should get count for full search update from #get_bulk_count' do
      described_class.any_instance.should_receive(:get_bulk_count).with(nil, '99').and_return 10
      post :bulk_update_fields, {sr_id:'99'}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 10
    end
  end
  describe 'bulk_update' do
    it 'should call bulk action runner with BulkOrderUpdate' do
      today = Date.today.to_s
      bar = OpenChain::BulkAction::BulkActionRunner
      bar.should_receive(:process_object_ids).with(@u,['1','2'], OpenChain::BulkAction::BulkOrderUpdate, {"ord_ord_date" => today})
      post :bulk_update, pk: {'0'=>'1','1'=>'2'}, mf_hsh: {"ord_ord_date" => today}
      expect(response).to be_success
    end
  end

  end
end
