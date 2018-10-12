require 'spec_helper'

describe BusinessValidationTemplatesController do
  before :each do

  end
  describe "index" do
    before :each do
      @bv_templates = [Factory(:business_validation_template)]
      u = Factory(:admin_user)
      sign_in_as u
    end
    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      get :index
      expect(response).to be_redirect
      expect(assigns(:bv_templates)).to be_nil
    end
    it "should load templates" do
      get :index
      expect(response).to be_success
      expect(assigns(:bv_templates)).to eq @bv_templates
    end
    it "should skip templates with delete_pending flag set" do
      Factory(:business_validation_template, delete_pending: true)
      get :index
      expect(response).to be_success
      expect(assigns(:bv_templates).count).to eq 1
    end
  end
  describe "show" do 
    before :each do 
      @t = Factory(:business_validation_template)
    end
    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      get :show, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end
    it "should load templates" do
      u = Factory(:admin_user)
      sign_in_as u
      get :show, id: @t.id
      expect(response).to be_success
      expect(assigns(:bv_template)).to eq @t
    end
  end

  describe "new" do

    before :each do
      @t = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      get :new, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should load the correct template" do
      u = Factory(:admin_user)
      sign_in_as u
      get :new, id: @t.id
      expect(response).to be_success
      expect(response.request.filtered_parameters["id"].to_i).to eq(@t.id)
    end

  end

  describe "create" do

    before :each do
      @t = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :create, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should create the correct template" do
      u = Factory(:admin_user)
      sign_in_as u
      post :create, id: @t.id
      expect(response).to be_success
      expect { BusinessValidationTemplate.find(@t.id) }.to_not raise_error
    end

  end

  describe "update" do

    before :each do
      @t = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :update, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should update criteria when search_criterions_only is set" do
      u = Factory(:admin_user)
      sign_in_as u
      post :update,
          id: @t.id,
          search_criterions_only: true,
          business_validation_template: {search_criterions: [{"mfid" => "ent_cust_name", 
              "datatype" => "string", "label" => "Customer Name", 
              "operator" => "eq", "value" => "Monica Lewinsky"}]}
      expect(@t.search_criterions.length).to eq(1)
      expect(@t.search_criterions.first.value).to eq("Monica Lewinsky")
    end

  end

  describe "edit" do

    before :each do
      @t = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      get :edit, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should load the correct template" do
      u = Factory(:admin_user)
      sign_in_as u
      get :edit, id: @t.id
      expect(response).to be_success
      expect(response.request.filtered_parameters["id"].to_i).to eq(@t.id)
    end

  end

  describe "destroy" do

    before :each do
      @t = Factory(:business_validation_template)
      u = Factory(:admin_user)
      sign_in_as u
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :destroy, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should call async_destroy on BVT as a Delayed Job and set delete_pending flag" do
      d = double("delay")
      expect(BusinessValidationTemplate).to receive(:delay).and_return d
      expect(d).to receive(:async_destroy).with @t.id
      post :destroy, id: @t.id
      @t.reload
      expect(@t.delete_pending).to eq true
    end

    it "marks rules as delete_pending" do
      Factory(:business_validation_rule, business_validation_template: @t)
      Factory(:business_validation_rule, business_validation_template: @t)
      post :destroy, id: @t.id
      expect(BusinessValidationRule.pluck(:delete_pending)).to eq [true, true]
    end

  end

  describe "edit_angular" do
    before :each do
      @sc = Factory(:search_criterion)
      @bvt = Factory(:business_validation_template, module_type: "Entry", search_criterions: [@sc])
    end

    it "should render the correct model_field and business_template json" do
      u = Factory(:admin_user)
      sign_in_as u
      get :edit_angular, id: @bvt.id
      r = JSON.parse(response.body)
      expect(r["model_fields"].length).to eq(CoreModule::ENTRY.default_module_chain.model_fields(u).values.size)
      temp = r["business_template"]["business_validation_template"]
      temp.delete("updated_at")
      temp.delete("created_at")
      expect(temp).to eq({"delete_pending"=>nil, "disabled"=>nil, "description"=>nil, "id"=>@bvt.id, "module_type"=>"Entry", "name"=>nil, "private"=>nil,
                          "search_criterions"=>[{"operator"=>"eq", "value"=>"x", "datatype"=>"string", "label"=>"Unique Identifier", "mfid"=>"prod_uid", "include_empty" => false}]})
    end
  end

end
