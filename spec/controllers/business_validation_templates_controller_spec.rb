describe BusinessValidationTemplatesController do
  describe "index" do
    let!(:business_validation_templates) { [create(:business_validation_template)] }

    before do
      sign_in_as create(:admin_user)
    end

    it "requires admin" do
      u = create(:user)
      sign_in_as u
      get :index
      expect(response).to be_redirect
      expect(assigns(:bv_templates)).to be_nil
    end

    it "loads templates" do
      get :index
      expect(response).to be_success
      expect(assigns(:bv_templates)).to eq business_validation_templates
    end

    it "skips templates with delete_pending flag set" do
      create(:business_validation_template, delete_pending: true)
      get :index
      expect(response).to be_success
      expect(assigns(:bv_templates).count).to eq 1
    end
  end

  describe "show" do
    let(:business_validation_template) { create(:business_validation_template) }

    it "requires admin" do
      u = create(:user)
      sign_in_as u
      get :show, id: business_validation_template.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "loads templates" do
      u = create(:admin_user)
      sign_in_as u
      get :show, id: business_validation_template.id
      expect(response).to be_success
      expect(assigns(:bv_template)).to eq business_validation_template
    end
  end

  describe "new" do
    let(:business_validation_template) { create(:business_validation_template) }

    it "requires admin" do
      u = create(:user)
      sign_in_as u
      get :new, id: business_validation_template.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "loads the correct template" do
      u = create(:admin_user)
      sign_in_as u
      get :new, id: business_validation_template.id
      expect(response).to be_success
      expect(response.request.filtered_parameters["id"].to_i).to eq(business_validation_template.id)
    end

  end

  describe "create" do

    it "requires admin" do
      u = create(:user)
      sign_in_as u
      expect { post :create, business_validation_template: { module_type: "Entry"} }.not_to change(BusinessValidationTemplate, :count)
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "creates the correct template" do
      u = create(:admin_user)
      sign_in_as u
      expect { post :create, business_validation_template: { module_type: "Entry"} }.to change(BusinessValidationTemplate, :count).from(0).to(1)
      expect(response).to be_redirect
    end

    it "errors if validation fails" do
      u = create(:admin_user)
      sign_in_as u
      expect { post :create, business_validation_template: { module_type: nil } }.not_to change(BusinessValidationTemplate, :count)
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Module type can't be blank"]
    end

  end

  describe "update" do
    let(:business_validation_template) { create(:business_validation_template, module_type: "Product") }

    it "requires admin" do
      u = create(:user)
      sign_in_as u
      post :update, id: business_validation_template.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "updates only main attributes when search_criterions_only not set" do
      u = create(:admin_user)
      sign_in_as u
      post :update,
           id: business_validation_template.id,
           search_criterions_only: false,
           business_validation_template: {module_type: "Entry", description: "description", disabled: true,
                                          name: "name", private: true, system_code: "SYS CODE",
                                          search_criterions: [{"mfid" => "ent_cust_name", "datatype" => "string", "label" => "Customer Name",
                                                               "operator" => "eq", "value" => "Nigel Tufnel"}]}
      expect(business_validation_template.reload.search_criterions.length).to eq(0)
      expect(business_validation_template.module_type).to eq "Entry"
      expect(business_validation_template.description).to eq "description"
      expect(business_validation_template.disabled).to eq true
      expect(business_validation_template.name).to eq "name"
      expect(business_validation_template.private).to eq true
      expect(business_validation_template.system_code).to eq "SYS CODE"
    end

    it "onlies update criteria when search_criterions_only is set" do
      u = create(:admin_user)
      sign_in_as u
      post :update,
           id: business_validation_template.id,
           search_criterions_only: true,
           business_validation_template: {module_type: "Entry", search_criterions: [{"mfid" => "ent_cust_name",
                                                                                     "datatype" => "string", "label" => "Customer Name",
                                                                                     "operator" => "eq", "value" => "Nigel Tufnel"}]}
      expect(business_validation_template.reload.search_criterions.length).to eq(1)
      expect(business_validation_template.search_criterions.first.value).to eq("Nigel Tufnel")
      expect(business_validation_template.module_type).to eq "Product"
    end

    it "errors if validation fails" do
      u = create(:admin_user)
      sign_in_as u
      post :update,
           id: business_validation_template.id,
           search_criterions_only: false,
           business_validation_template: {module_type: nil, search_criterions: [{"mfid" => "ent_cust_name",
                                                                                 "datatype" => "string", "label" => "Customer Name",
                                                                                 "operator" => "eq", "value" => "Nigel Tufnel"}]}
      expect(business_validation_template.reload.search_criterions.length).to eq(0)
      expect(flash[:errors]).to eq ["Module type can't be blank"]
      expect(response).to be_redirect
    end

  end

  describe "edit" do
    let(:business_validation_template) { create(:business_validation_template) }

    it "requires admin" do
      u = create(:user)
      sign_in_as u
      get :edit, id: business_validation_template.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "loads the correct template" do
      u = create(:admin_user)
      sign_in_as u
      get :edit, id: business_validation_template.id
      expect(response).to be_success
      expect(response.request.filtered_parameters["id"].to_i).to eq(business_validation_template.id)
    end

  end

  describe "destroy" do
    let(:business_validation_template) { create(:business_validation_template) }

    before do
      sign_in_as create(:admin_user)
    end

    it "requires admin" do
      u = create(:user)
      sign_in_as u
      post :destroy, id: business_validation_template.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "calls async_destroy on BVT as a Delayed Job and set delete_pending flag" do
      d = instance_double("delay")
      expect(BusinessValidationTemplate).to receive(:delay).and_return d
      expect(d).to receive(:async_destroy).with business_validation_template.id
      post :destroy, id: business_validation_template.id
      business_validation_template.reload
      expect(business_validation_template.delete_pending).to eq true
    end

    it "marks rules as delete_pending" do
      create(:business_validation_rule, business_validation_template: business_validation_template)
      create(:business_validation_rule, business_validation_template: business_validation_template)
      post :destroy, id: business_validation_template.id
      expect(BusinessValidationRule.pluck(:delete_pending)).to eq [true, true]
    end

  end

  describe "upload", :disable_delayed_jobs do
    let(:user) { create(:admin_user) }
    let(:file) { instance_double("file") }
    let(:cf) { instance_double("custom file") }
    let(:uploader) { OpenChain::BusinessRulesCopier::TemplateUploader }

    before {sign_in_as user}

    it "processes file with rule copier" do
      allow(cf).to receive(:id).and_return 1
      expect(CustomFile).to receive(:create!).with(file_type: uploader.to_s, uploaded_by: user, attached: file.to_s).and_return cf
      expect(CustomFile).to receive(:process).with(1, user.id)
      put :upload, attached: file
      expect(response).to redirect_to business_validation_templates_path
      expect(flash[:notices]).to include "Your file is being processed. You'll receive a " + MasterSetup.application_name + " message when it completes."
    end

    it "only allows admin" do
      user = create(:user)
      sign_in_as user
      expect(CustomFile).not_to receive(:create!)
    end

    it "errors if no file submitted" do
      put :upload, attached: nil
      expect(CustomFile).not_to receive(:create!)
      expect(flash[:errors]).to include "You must select a file to upload."
    end
  end

  describe "copy", :disable_delayed_jobs do
    let(:user) { create(:admin_user) }
    let(:bvt) { create(:business_validation_template) }

    before { sign_in_as user }

    it "copies template" do
      expect(OpenChain::BusinessRulesCopier).to receive(:copy_template).with user.id, bvt.id
      post :copy, id: bvt.id
      expect(response).to redirect_to business_validation_templates_path
      expect(flash[:notices]).to include "Business Validation Template is being copied. You'll receive a " + MasterSetup.application_name + " message when it completes."
    end

    it "only allows admin" do
      user = create(:user)
      sign_in_as user
      expect(OpenChain::BusinessRulesCopier).not_to receive(:copy_template)
      post :copy, id: bvt.id
    end
  end

  describe "edit_angular" do
    let(:search_criterion) { create(:search_criterion) }
    let(:business_validation_template) { create(:business_validation_template, module_type: "Entry", search_criterions: [search_criterion]) }

    it "renders the correct model_field and business_template json" do
      u = create(:admin_user)
      sign_in_as u
      get :edit_angular, id: business_validation_template.id
      r = JSON.parse(response.body)
      expect(r["model_fields"].length).to eq(CoreModule::ENTRY.default_module_chain.model_fields(u).values.size)
      temp = r["business_template"]["business_validation_template"]
      temp.delete("updated_at")
      temp.delete("created_at")
      expect(temp).to eq({"delete_pending" => nil, "disabled" => nil, "description" => nil, "id" => business_validation_template.id,
                          "module_type" => "Entry", "name" => nil, "private" => nil, "system_code" => nil,
                          "search_criterions" => [{"operator" => "eq", "value" => "x", "datatype" => "string",
                                                   "label" => "Unique Identifier", "mfid" => "prod_uid", "include_empty" => false}]})
    end
  end

end
