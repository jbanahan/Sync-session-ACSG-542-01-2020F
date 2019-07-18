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

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      expect{ post :create, business_validation_template: { module_type: "Entry"} }.to_not change(BusinessValidationTemplate, :count)
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should create the correct template" do
      u = Factory(:admin_user)
      sign_in_as u
      expect{ post :create, business_validation_template: { module_type: "Entry"} }.to change(BusinessValidationTemplate, :count).from(0).to(1)
      expect(response).to be_redirect
    end

    it "errors if validation fails" do
      u = Factory(:admin_user)
      sign_in_as u
      expect{ post :create, business_validation_template: { module_type: nil } }.to_not change(BusinessValidationTemplate, :count)
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Module type can't be blank"]
    end

  end

  describe "update" do

    before :each do
      @t = Factory(:business_validation_template, module_type: "Product")
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :update, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "updates only main attributes when search_criterions_only not set" do
      u = Factory(:admin_user)
      sign_in_as u
      post :update,
          id: @t.id,
          search_criterions_only: false,
          business_validation_template: {module_type: "Entry", description: "description", disabled: true, 
                                         name: "name", private: true, system_code: "SYS CODE",
                                         search_criterions: [{"mfid" => "ent_cust_name", "datatype" => "string", "label" => "Customer Name", 
                                                              "operator" => "eq", "value" => "Nigel Tufnel"}]}
      expect(@t.reload.search_criterions.length).to eq(0)
      expect(@t.module_type).to eq "Entry"
      expect(@t.description).to eq "description"
      expect(@t.disabled).to eq true
      expect(@t.name).to eq "name"
      expect(@t.private).to eq true
      expect(@t.system_code).to eq "SYS CODE"
    end

    it "should only update criteria when search_criterions_only is set" do
      u = Factory(:admin_user)
      sign_in_as u
      post :update,
          id: @t.id,
          search_criterions_only: true,
          business_validation_template: {module_type: "Entry", search_criterions: [{"mfid" => "ent_cust_name", 
              "datatype" => "string", "label" => "Customer Name", 
              "operator" => "eq", "value" => "Nigel Tufnel"}]}
      expect(@t.reload.search_criterions.length).to eq(1)
      expect(@t.search_criterions.first.value).to eq("Nigel Tufnel")
      expect(@t.module_type).to eq "Product"
    end

    it "errors if validation fails" do
      u = Factory(:admin_user)
      sign_in_as u
      post :update,
          id: @t.id,
          search_criterions_only: false,
          business_validation_template: {module_type: nil, search_criterions: [{"mfid" => "ent_cust_name", 
              "datatype" => "string", "label" => "Customer Name", 
              "operator" => "eq", "value" => "Nigel Tufnel"}]}
      expect(@t.reload.search_criterions.length).to eq(0)
      expect(flash[:errors]).to eq ["Module type can't be blank"]
      expect(response).to be_redirect
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

  describe "upload", :disable_delayed_jobs do
    let(:user) { Factory(:admin_user) }
    let(:file) { double "file"}
    let(:cf) { double "custom file" }
    let(:uploader) { OpenChain::BusinessRulesCopier::TemplateUploader }
    before {sign_in_as user}

    it "processes file with rule copier" do
      allow(cf).to receive(:id).and_return 1
      expect(CustomFile).to receive(:create!).with(file_type: uploader.to_s, uploaded_by: user, attached: file.to_s).and_return cf
      expect(CustomFile).to receive(:process).with(1, user.id)
      put :upload, attached: file
      expect(response).to redirect_to business_validation_templates_path
      expect(flash[:notices]).to include "Your file is being processed. You'll receive a VFI Track message when it completes."
    end

    it "only allows admin" do
      user = Factory(:user)
      sign_in_as user     
      expect(CustomFile).to_not receive(:create!)
    end

    it "errors if no file submitted" do
      put :upload, attached: nil
      expect(CustomFile).to_not receive(:create!)
      expect(flash[:errors]).to include "You must select a file to upload."
    end
  end

  describe "copy", :disable_delayed_jobs do
    let(:user) { Factory(:admin_user) }
    let(:bvt) { Factory(:business_validation_template) }

    before { sign_in_as user }

    it "copies template" do
      expect(OpenChain::BusinessRulesCopier).to receive(:copy_template).with user.id, bvt.id
      post :copy, id: bvt.id
      expect(response).to redirect_to business_validation_templates_path
      expect(flash[:notices]).to include "Business Validation Template is being copied. You'll receive a VFI Track message when it completes."      
    end

    it "only allows admin" do
      user = Factory(:user)
      sign_in_as user
      expect(OpenChain::BusinessRulesCopier).to_not receive(:copy_template)
      post :copy, id: bvt.id
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
      expect(temp).to eq({"delete_pending"=>nil, "disabled"=>nil, "description"=>nil, "id"=>@bvt.id, "module_type"=>"Entry", "name"=>nil, "private"=>nil, "system_code"=>nil,
                          "search_criterions"=>[{"operator"=>"eq", "value"=>"x", "datatype"=>"string", "label"=>"Unique Identifier", "mfid"=>"prod_uid", "include_empty" => false}]})
    end
  end

end
