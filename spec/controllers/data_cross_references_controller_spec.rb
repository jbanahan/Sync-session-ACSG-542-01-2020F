require 'spec_helper'

describe DataCrossReferencesController do

  before :each do
    ms = double("MasterSetup")
    allow(MasterSetup).to receive(:get).and_return ms
    allow(ms).to receive(:system_code).and_return "polo"

    @user = Factory(:admin_user)
    sign_in_as @user
  end

  describe "index" do
    it "shows index page" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      get :index, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC

      expect(response).to be_success
      expect(assigns(:xref_info)).to eq DataCrossReference.xref_edit_hash(@user)[DataCrossReference::RL_VALIDATED_FABRIC].with_indifferent_access
      expect(assigns(:xrefs).first).to eq xref
      # Just ensure that the search is utilized by checking for one of the values it assigns
      expect(assigns(:search)).not_to be_nil
    end

    it "runs a search" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"
      xref2 = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY2", value: "ZValue"
      xref3 = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "NO", value: "Value"

      get :index, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, f: "`key`", c: "contains", s: "KEY", sf: "`key`", so: "d"

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
      Factory(:importer, importer_products: [Factory(:product)])
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      get :edit, id: xref.id
      expect(response).to be_success
      expect(assigns(:xref_info)).to eq DataCrossReference.xref_edit_hash(@user)[DataCrossReference::RL_VALIDATED_FABRIC].with_indifferent_access
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
      Factory(:importer, importer_products: [Factory(:product)])

      get :new, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      expect(response).to be_success
      expect(assigns(:xref_info)).to eq DataCrossReference.xref_edit_hash(@user)[DataCrossReference::RL_VALIDATED_FABRIC].with_indifferent_access
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
      expect(assigns(:xref_info)).to eq DataCrossReference.xref_edit_hash(@user)[DataCrossReference::RL_VALIDATED_FABRIC].with_indifferent_access
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
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"
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
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      post :create, data_cross_reference: {key: "KEY", value: "CREATE", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC}
      expect(response).to be_success
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
    let!(:xref) { DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE" }

    it "returns CSV file" do
      get :download, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      expect(response).to be_success
      expect(response.body.split("\n").count).to eq 2
    end

    it "rejects user without access" do
      expect(DataCrossReference).to receive(:can_view?).with(DataCrossReference::RL_VALIDATED_FABRIC, @user).and_return false

      get :download, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to download this file."
    end
  end

  describe "get_importers" do
    it "returns an array of importers with products, sorted by name" do
      co_1 = Factory(:company)
      prod_1 = Factory(:product, importer: co_1)
      
      co_2 = Factory(:importer, name: "Substandard Ltd.")
      prod_2 = Factory(:product, importer: co_2)
      
      co_3 = Factory(:importer, name: "ACME")
      prod_3 = Factory(:product, importer: co_3)
      prod_4 = Factory(:product, importer: co_3)

      co_4 = Factory(:importer, name: "Nothing-to-See")
      
      results = described_class.new.get_importers
      expect(results.count).to eq 2
      expect(results[0]).to eq co_3
      expect(results[1]).to eq co_2
    end
  end

end