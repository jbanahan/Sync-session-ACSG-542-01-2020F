require 'spec_helper'

describe OrdersController do

  before :each do
    ms = stub_master_setup
    allow(ms).to receive(:order_enabled).and_return true
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

  describe "accept" do
    it "should accept if user has permission" do
      expect_any_instance_of(Order).to receive(:async_accept!).with(@u)
      allow_any_instance_of(Order).to receive(:can_accept?).and_return true
      o = Factory(:order)
      post :accept, id: o.id
      expect(response).to redirect_to o
    end
    it "should error if user does not have permission" do
      expect_any_instance_of(Order).not_to receive(:async_accept!)
      allow_any_instance_of(Order).to receive(:can_accept?).and_return false
      o = Factory(:order)
      post :accept, id: o.id
    end
    it "should error if order cannot be accepted" do
      expect_any_instance_of(Order).not_to receive(:async_accept!)
      allow_any_instance_of(Order).to receive(:can_accept?).and_return true
      allow_any_instance_of(Order).to receive(:can_be_accepted?).and_return false
      o = Factory(:order)
      post :accept, id: o.id
    end
  end

  describe "unaccept" do
    it "should unaccept if user has permission" do
      expect_any_instance_of(Order).to receive(:async_unaccept!).with(@u)
      allow_any_instance_of(Order).to receive(:can_accept?).and_return true
      o = Factory(:order)
      post :unaccept, id: o.id
      expect(response).to redirect_to o
    end
    it "should error if user does not have permission" do
      expect_any_instance_of(Order).not_to receive(:async_unaccept!)
      allow_any_instance_of(Order).to receive(:can_accept?).and_return false
      o = Factory(:order)
      post :unaccept, id: o.id
    end
  end

  describe "close" do
    it "should close if user has permission" do
      allow_any_instance_of(Order).to receive(:can_close?).and_return true
      o = Factory(:order)
      post :close, id: o.id
      expect(response).to redirect_to o
      o.reload
      expect(o.closed_by).to eq @u
      expect(o.closed_at).to be > 1.minute.ago
    end
    it "should error if user cannot close" do
      allow_any_instance_of(Order).to receive(:can_close?).and_return false
      o = Factory(:order)
      post :close, id: o.id
      expect(response).to be_redirect
      o.reload
      expect(o.closed_by).to be_nil
      expect(o.closed_at).to be_nil
    end
  end
  describe "reopen" do
    before :each do
      @o = Factory(:order,closed_at:Time.now)
    end
    it "should reopen if user can close" do
      allow_any_instance_of(Order).to receive(:can_close?).and_return true
      post :reopen, id: @o.id
      expect(response).to redirect_to @o
      @o.reload
      expect(@o.closed_at).to be_nil
    end
    it "should error if user cannot close" do
      allow_any_instance_of(Order).to receive(:can_close?).and_return false
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
      allow_any_instance_of(Order).to receive(:can_view?).with(@u).and_return true
      allow_any_instance_of(BusinessValidationResult).to receive(:can_view?).with(@u).and_return true
      allow_any_instance_of(User).to receive(:view_business_validation_results?).and_return true
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
  end

  describe 'bulk_update_fields' do
    it "returns list of model fields for user to edit" do
      FieldValidatorRule.create!(model_field_uid: 'ord_ord_date', module_type: 'Order', mass_edit: true)
      post :bulk_update_fields
      expect(JSON.parse(response.body)["mf_hsh"]).to include({"ord_ord_date" => "Order Date"})
    end
    it "skips model fields that user isn't authorized to edit" do
      allow_any_instance_of(ModelField).to receive(:can_edit?).and_return false
      post :bulk_update_fields
      expect(JSON.parse(response.body)["mf_hsh"]).to be_empty
    end
    it 'should get count for specific items from #get_bulk_count' do
      expect_any_instance_of(described_class).to receive(:get_bulk_count).with({"0"=>"99","1"=>"54"}, nil).and_return 2
      post :bulk_update_fields, {"pk" => {"0"=>"99","1"=>"54"}}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 2
    end
    it 'should get count for full search update from #get_bulk_count' do
      expect_any_instance_of(described_class).to receive(:get_bulk_count).with(nil, '99').and_return 10
      post :bulk_update_fields, {sr_id:'99'}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 10
    end
  end

  describe 'bulk_update' do
    it 'should call bulk action runner with BulkOrderUpdate' do
      today = Date.today.to_s
      bar = OpenChain::BulkAction::BulkActionRunner
      expect(bar).to receive(:process_object_ids).with(@u,['1','2'], OpenChain::BulkAction::BulkOrderUpdate, {"ord_ord_date" => today})
      post :bulk_update, pk: {'0'=>'1','1'=>'2'}, mf_hsh: {"ord_ord_date" => today}
      expect(response).to be_success
    end
  end

  describe 'bulk_send_to_sap' do
    it 'should call bulk action runner with BulkSendToSap' do
      request.env["HTTP_REFERER"] = "blah"
      bar = OpenChain::BulkAction::BulkActionRunner
      expect(bar).to receive(:process_from_parameters).with(@u, {"pk"=>{"0"=>"1", "1"=>"2"}, "controller"=>"orders", "action"=>"bulk_send_to_sap"}, OpenChain::CustomHandler::LumberLiquidators::BulkSendToSap, {max_results:100})

      post :bulk_send_to_sap, pk: {'0'=>'1','1'=>'2'};

      expect(response).to redirect_to("blah")
      expect(flash[:errors]).to be_blank
      expect(flash[:notices].first).to eq("Documents have been requested for transmission to SAP.  Please allow a few minutes for them to be sent.")
    end

    it 'should handle bulk SAP send requests without a referer' do
      request.env["HTTP_REFERER"] = nil
      bar = OpenChain::BulkAction::BulkActionRunner
      expect(bar).to receive(:process_from_parameters).with(@u, {"pk"=>{"0"=>"1", "1"=>"2"}, "controller"=>"orders", "action"=>"bulk_send_to_sap"}, OpenChain::CustomHandler::LumberLiquidators::BulkSendToSap, {max_results:100})

      post :bulk_send_to_sap, pk: {'0'=>'1','1'=>'2'};

      expect(response).to redirect_to("/")
      expect(flash[:errors]).to be_blank
      expect(flash[:notices].first).to eq("Documents have been requested for transmission to SAP.  Please allow a few minutes for them to be sent.")
    end

    it 'should handle excessive objects gracefully' do
      request.env["HTTP_REFERER"] = "blah"
      bar = OpenChain::BulkAction::BulkActionRunner
      expect(bar).to receive(:process_from_parameters).with(@u, {"pk"=>{"0"=>"1", "1"=>"2"}, "controller"=>"orders", "action"=>"bulk_send_to_sap"}, OpenChain::CustomHandler::LumberLiquidators::BulkSendToSap, {max_results:100}).and_raise(OpenChain::BulkAction::TooManyBulkObjectsError)

      post :bulk_send_to_sap, pk: {'0'=>'1','1'=>'2'};

      expect(response).to redirect_to("blah")
      expect(flash[:errors].first).to eq("You may not send more than 100 orders to SAP at one time.")
      expect(flash[:notices]).to be_blank
    end
  end

  describe 'send_to_sap' do
    it 'should call BulkSendToSap to send the file' do
      request.env["HTTP_REFERER"] = "blah"

      order_id = Random.new.rand(500)

      bulk = OpenChain::CustomHandler::LumberLiquidators::BulkSendToSap
      expect(bulk).to receive(:delay).and_return bulk
      expect(bulk).to receive(:act).with(@u, order_id.to_s, {}, nil, nil)

      get :send_to_sap, id: order_id

      expect(response).to redirect_to("blah")
      expect(flash[:errors]).to be_blank
      expect(flash[:notices].first).to eq("Document has been requested for transmission to SAP.  Please allow a few minutes for it to be sent.")
    end

    it 'should handle SAP send requests without a referer' do
      request.env["HTTP_REFERER"] = nil

      order_id = Random.new.rand(500)

      bulk = OpenChain::CustomHandler::LumberLiquidators::BulkSendToSap
      expect(bulk).to receive(:delay).and_return bulk
      expect(bulk).to receive(:act).with(@u, order_id.to_s, {}, nil, nil)

      get :send_to_sap, id: order_id

      expect(response).to redirect_to("/")
      expect(flash[:errors]).to be_blank
      expect(flash[:notices].first).to eq("Document has been requested for transmission to SAP.  Please allow a few minutes for it to be sent.")
    end
  end

end