require 'spec_helper'

describe DataCrossReferencesController do

  before :each do
    ms = double("MasterSetup")
    MasterSetup.stub(:get).and_return ms
    ms.stub(:system_code).and_return "polo"

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
    end

    it "rejects user without access" do
      get :index, cross_reference_type: "not_an_xref"

      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to view this cross reference type."
    end
  end

  describe "edit" do
    it "shows edit page" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      get :edit, id: xref.id
      expect(response).to be_success
      expect(assigns(:xref_info)).to eq DataCrossReference.xref_edit_hash(@user)[DataCrossReference::RL_VALIDATED_FABRIC].with_indifferent_access
      expect(assigns(:xref)).to eq xref
    end

    it "rejects user without access" do
      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"
      DataCrossReference.any_instance.should_receive(:can_view?).and_return false
      get :edit, id: xref.id

      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to edit this cross reference."
    end
  end

  describe "new" do
    it "shows new page" do
      get :new, cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      expect(response).to be_success
      expect(assigns(:xref_info)).to eq DataCrossReference.xref_edit_hash(@user)[DataCrossReference::RL_VALIDATED_FABRIC].with_indifferent_access
      expect(assigns(:xref)).not_to be_nil
      expect(assigns(:xref).cross_reference_type).to eq DataCrossReference::RL_VALIDATED_FABRIC
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

      xref = DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE"

      post :update, id: xref.id, data_cross_reference: {value: "Update", cross_reference_type: xref.cross_reference_type}
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to edit this cross reference."
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

end