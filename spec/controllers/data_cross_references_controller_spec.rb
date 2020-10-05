describe DataCrossReferencesController do

  # no two lambdas share the same identity so this simplifies the tests
  def strip_preproc hsh
    hsh.delete(:preprocessor)
    hsh
  end

  let(:user) { Factory(:admin_user) }

  before do
    ms = stub_master_setup
    allow(ms).to receive(:custom_feature?).with("Polo").and_return true

    sign_in_as user
  end

  describe "index" do
    it "shows index page" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      get :index, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC

      expect(response).to be_success
      expect(strip_preproc(assigns(:xref_info))).to eq strip_preproc(DataCrossReference.xref_edit_hash(user)[DataCrossReference::RL_VALIDATED_FABRIC])
      expect(assigns(:xrefs).first).to eq xref
      # Just ensure that the search is utilized by checking for one of the values it assigns
      expect(assigns(:search)).not_to be_nil
    end

    it "runs a search" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"
      xref2 = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY2", value: "ZValue"

      get :index, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, f1: "d_key", c1: "contains", s1: "KEY", sf: "d_key", so: "d"

      expect(response).to be_success
      xrefs = assigns(:xrefs)
      expect(xrefs.length).to eq 2
      expect(xrefs.first).to eq xref2
      expect(xrefs.second).to eq xref
    end

    it "rejects user without access" do
      get :index, cross_reference_type: "not_an_xref"

      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to view this cross reference type."
    end
  end

  describe "edit" do
    it "shows edit page" do
      Factory(:importer, importer_products: [Factory(:product)], system_code: 'IMPORTER')
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      get :edit, id: xref.id
      expect(response).to be_success
      expect(strip_preproc(assigns(:xref_info))).to eq strip_preproc(DataCrossReference.xref_edit_hash(user)[DataCrossReference::RL_VALIDATED_FABRIC])
      expect(assigns(:xref)).to eq xref
      expect(assigns(:importers).count).to eq 1
    end

    it "rejects user without access" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"
      expect_any_instance_of(DataCrossReference).to receive(:can_view?).and_return false
      get :edit, id: xref.id

      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to edit this cross reference."
    end
  end

  describe "new" do
    it "shows new page" do
      Factory(:importer, importer_products: [Factory(:product)], system_code: 'IMPORTER')

      get :new, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      expect(response).to be_success
      expect(strip_preproc(assigns(:xref_info))).to eq strip_preproc(DataCrossReference.xref_edit_hash(user)[DataCrossReference::RL_VALIDATED_FABRIC])
      expect(assigns(:xref)).not_to be_nil
      expect(assigns(:xref).cross_reference_type).to eq DataCrossReference::RL_VALIDATED_FABRIC
      expect(assigns(:importers).count).to eq 1
    end

    it "rejects user without access" do
      get :new, cross_reference_type: "not a cross ref"

      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to edit this cross reference."
    end
  end

  describe "show" do
    it "shows edit page" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      get :edit, id: xref.id
      expect(response).to be_success
      expect(strip_preproc(assigns(:xref_info))).to eq strip_preproc(DataCrossReference.xref_edit_hash(user)[DataCrossReference::RL_VALIDATED_FABRIC])
      expect(assigns(:xref)).to eq xref
    end
  end

  describe "update" do
    it "updates an xref" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      post :update, id: xref.id, data_cross_reference: {value: "Update", cross_reference_type: xref.cross_reference_type}
      expect(response).to redirect_to data_cross_references_path(cross_reference_type: xref.cross_reference_type)
      expect(flash[:notices]).to include "Cross Reference was successfully updated."
      expect(DataCrossReference.where(key: "KEY").first.value).to eq "Update"
    end

    it "rejects user without access" do
      user = Factory(:user)
      sign_in_as user

      xref = DataCrossReference.create! cross_reference_type: "bogus", key: "KEY", value: "VALUE"

      post :update, id: xref.id, data_cross_reference: {value: "Update", cross_reference_type: xref.cross_reference_type}
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to edit this cross reference."
    end

    it "errors on duplicate keys" do
      DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"
      xref2 = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY2", value: "VALUE"

      post :update, id: xref2.id, data_cross_reference: {key: "KEY", cross_reference_type: xref2.cross_reference_type}
      expect(response).to be_success
      expect(flash[:errors]).to include "The Approved Fiber value 'KEY' already exists on another cross reference record."
      expect(assigns(:xref)).not_to be_nil
    end

    it "errors if missing required company" do
      allow(DataCrossReference).to receive(:can_view?).and_return true
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::US_HTS_TO_CA, key: "KEY", value: "VALUE"

      post :update, id: xref.id, data_cross_reference: {key: "KEY", value: "VALUE2", cross_reference_type: xref.cross_reference_type}
      expect(response).to be_success
      expect(flash[:errors]).to include "You must assign a company."
      expect(assigns(:xref)).not_to be_nil
      expect(DataCrossReference.where(key: "KEY").first.value).to eq "VALUE"
    end
  end

  describe "create" do
    it "creates an xref" do
      post :create, data_cross_reference: {key: "KEY", value: "CREATE", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC}
      expect(response).to redirect_to data_cross_references_path(cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC)
      expect(flash[:notices]).to include "Cross Reference was successfully created."
      expect(DataCrossReference.where(key: "KEY").first).not_to be_nil
    end

    it "rejects user without access" do
      post :create, data_cross_reference: {key: "KEY", value: "CREATE", cross_reference_type: "blah"}
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to create this cross reference."
    end

    it "errors on duplicate keys" do
      DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      post :create, data_cross_reference: {key: "KEY", value: "CREATE", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "The Approved Fiber value 'KEY' already exists on another cross reference record."
      expect(assigns(:xref)).not_to be_nil
    end

    it "errors if missing required company" do
      allow(DataCrossReference).to receive(:can_view?).and_return true

      post :create, data_cross_reference: {key: "KEY", value: "CREATE", cross_reference_type: DataCrossReference::US_HTS_TO_CA}
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You must assign a company."
    end
  end

  describe "destroy" do
    it "destroys an xref" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"
      post :destroy, id: xref.id

      expect(response).to redirect_to data_cross_references_path(cross_reference_type: xref.cross_reference_type)
      expect(flash[:notices]).to include "Cross Reference was successfully deleted."
    end

    it "rejects user without access" do
      xref = DataCrossReference.create! cross_reference_type: "not an xref", key: "KEY", value: "VALUE"

      post :destroy, id: xref.id
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to delete this cross reference."
    end
  end

  describe "download" do
    before do
      DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"
    end

    it "returns CSV file" do
      get :download, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      expect(response).to be_success
      expect(response.body.split("\n").count).to eq 2
    end

    it "rejects user without access" do
      expect(DataCrossReference).to receive(:can_view?).with(DataCrossReference::RL_VALIDATED_FABRIC, user).and_return false

      get :download, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to download this file."
    end
  end

  describe "upload" do
    it "uploads", :disable_delayed_jobs do
      file = fixture_file_upload('/files/test_sheet_3.csv', 'text/csv')
      cf = instance_double "custom file"
      allow(cf).to receive(:id).and_return 1
      expect(CustomFile).to receive(:create!).with(file_type: 'OpenChain::DataCrossReferenceUploader', uploaded_by: user, attached: file).and_return cf
      expect(CustomFile).to receive(:process).with(1, user.id, cross_reference_type: 'cross_ref_type', company_id: nil)
      expect(DataCrossReference).to receive(:can_view?).with('cross_ref_type', user).and_return true

      post :upload, cross_reference_type: 'cross_ref_type', attached: file
      expect(response).to redirect_to request.referer
      expect(flash[:notices]).to eq ["Your file is being processed.  You'll receive a " + MasterSetup.application_name + " message when it completes."]
    end

    it "returns error if attachment missing" do
      expect(DataCrossReference).to receive(:can_view?).with('cross_ref_type', user).and_return true

      post :upload, cross_reference_type: 'cross_ref_type', attached: nil

      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq ["You must select a file to upload."]
    end

    it "rejects wrong file type" do
      expect(DataCrossReference).to receive(:can_view?).with('cross_ref_type', user).and_return true
      file = fixture_file_upload('/files/test_sheet_4.txt', 'text/plain')
      expect_any_instance_of(OpenChain::DataCrossReferenceUploader).not_to receive(:process)

      post :upload, cross_reference_type: 'cross_ref_type', attached: file

      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq ["Only XLS, XLSX, and CSV files are accepted."]
    end

    it "prevents unauthorized access" do
      expect(DataCrossReference).to receive(:can_view?).with('cross_ref_type', user).and_return false
      user.sys_admin = false; user.save!
      file = fixture_file_upload('/files/test_sheet_3.csv', 'text/csv')
      expect_any_instance_of(OpenChain::DataCrossReferenceUploader).not_to receive(:process)

      post :upload, cross_reference_type: 'cross_ref_type', attached: file
    end

  end

  describe "get_importers" do
    it "returns an array of importers with products, sorted by name" do
      co_1 = Factory(:company)
      Factory(:product, importer: co_1)

      co_2 = Factory(:importer, name: "Substandard Ltd.", system_code: 'SUBST')
      Factory(:product, importer: co_2)

      co_3 = Factory(:importer, name: "ACME", system_code: 'ACME')
      Factory(:product, importer: co_3)
      Factory(:product, importer: co_3)

      Factory(:importer, name: "Nothing-to-See")

      results = described_class.new.get_importers_for(user)
      expect(results.count).to eq 2
      expect(results[0]).to eq co_3
      expect(results[1]).to eq co_2
    end
  end
end
