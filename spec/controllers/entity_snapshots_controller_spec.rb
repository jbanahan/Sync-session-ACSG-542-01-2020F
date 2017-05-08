require 'spec_helper'

describe EntitySnapshotsController do
  let (:product) { Factory(:product,:name=>'nm') }
  let (:user) { Factory(:user) }
  let (:snapshot) { product.create_snapshot user }

  describe "restore", :snapshot do
    before :each do
      snapshot
      product.update_attributes!(:name=>'new name')
      allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)

      sign_in_as user
    end
    it "should restore object" do
      post :restore, :id=>snapshot.id
      expect(response).to redirect_to product
      expect(flash[:notices].first).to eq("Object restored successfully.")
      product.reload
      expect(product.name).to eq('nm')
    end
    it "should not restore if user cannot edit parent object" do
      allow_any_instance_of(Product).to receive(:can_edit?).and_return(false)
      post :restore, :id=>snapshot.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].first).to eq("You cannot restore this object because you do not have permission to edit it.")
      product.reload
      expect(product.name).to eq('new name')
    end
  end

  describe "download" do
    let (:admin_user) { Factory(:sys_admin_user) }
    before :each do 
      sign_in_as admin_user
    end

    it "redirects to a download link" do
      expect_any_instance_of(EntitySnapshot).to receive(:snapshot_download_link) do |inst|
        expect(inst).to eq snapshot
        "url"
      end

      get :download, id: snapshot.id
      expect(response).to redirect_to "url"
    end

    it "errors if users is not admin" do
      sign_in_as user

      get :download, id: snapshot.id
      expect(response).not_to be_success
    end
  end

  describe "download_integration_file" do
    let (:snapshot) { product.create_snapshot user }
    let (:admin_user) { Factory(:sys_admin_user) }
    before :each do 
      sign_in_as admin_user
    end

    it "redirects to a download link" do
      expect_any_instance_of(EntitySnapshot).to receive(:s3_integration_file_context?).and_return true
      expect_any_instance_of(EntitySnapshot).to receive(:s3_integration_file_context_download_link) do |inst|
        expect(inst).to eq snapshot
        "url"
      end

      get :download_integration_file, id: snapshot.id
      expect(response).to redirect_to "url"
    end

    it "raises an error if not an integration file" do
      expect_any_instance_of(EntitySnapshot).to receive(:s3_integration_file_context?).and_return false
      expect { get :download_integration_file, id: snapshot.id }.to raise_error ActiveRecord::RecordNotFound
    end

    it "errors if users is not admin" do
      sign_in_as user

      get :download_integration_file, id: snapshot.id
      expect(response).not_to be_success
    end
  end
end
