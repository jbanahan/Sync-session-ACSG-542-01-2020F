require 'spec_helper'

describe Api::V1::FoldersController do

  let (:user) { Factory(:user) }
  let (:base_object) { Factory(:order) }
  let (:folder) { 
    base_object.folders.create! name: "Folder Name", created_by: user
  }

  before :each do
    allow_api_user user
    use_json
  end

  describe "show" do
    context "when user can view order" do
      before :each do
        Order.any_instance.stub(:can_view?).and_return true
        Folder.any_instance.stub(:can_view?).and_return true
        Folder.any_instance.stub(:can_edit?).and_return true
        Folder.any_instance.stub(:can_comment?).and_return true
        Folder.any_instance.stub(:can_attach?).and_return true
      end

      it "retrieves folder data" do
        get :show, base_object_type: "orders", base_object_id: base_object.id, id: folder.id
        expect(response).to be_success
        json = JSON.parse response.body
        expect(json).to eq({"folder" => {"id" => folder.id, "fld_name" => "Folder Name", "fld_created_at" => folder.created_at.iso8601, "fld_created_by_username"=> user.username, "fld_created_by_fullname"=>user.full_name, "fld_created_by"=>user.id, "attachments"=>[], "comments"=>[], "groups"=>[],
            "permissions" => {"can_edit"=> true, "can_attach" => true, "can_comment" => true}
          }})
      end

      it "retrieves folder, attachment, comment, and group information" do
        att = folder.attachments.create! attached_file_name: "file.txt", uploaded_by: user
        comment = folder.comments.create! user: user, subject: "Subject", body: "Body"
        group = Group.use_system_group "code"
        folder.groups << group

        get :show, base_object_type: "orders", base_object_id: base_object.id, id: folder.id, include: "attachments, comments, groups"
        expect(response).to be_success
        json = JSON.parse response.body

        att_json = json['folder']['attachments'].first
        expect(att_json['id']).to eq att.id
        expect(att_json['att_file_name']).to eq "file.txt"
        expect(att_json['att_uploaded_by_username']).to eq user.username

        com_json = json['folder']['comments'].first
        expect(com_json['id']).to eq comment.id
        expect(com_json['cmt_subject']).to eq "Subject"
        expect(com_json['permissions'].length).not_to eq 0
        expect(com_json['permissions']['can_view']).to be_true
        expect(com_json['permissions']['can_edit']).to be_true
        expect(com_json['permissions']['can_delete']).to be_true

        grp_json = json['folder']['groups'].first
        expect(grp_json['id']).to eq group.id
        expect(grp_json['grp_name']).to eq "code"
      end
    end

    it "fails if user cannot view object" do
      Order.any_instance.should_receive(:can_view?).with(user).and_return false
      get :show, base_object_type: "orders", base_object_id: base_object.id, id: folder.id
      expect(response).not_to be_success
      json = JSON.parse response.body
      expect(json['errors']).to eq ["Access denied."]
    end

    it "fails if user cannot view folder" do
      Order.any_instance.should_receive(:can_view?).with(user).and_return true
      Folder.any_instance.should_receive(:can_view?).with(user).and_return false

      get :show, base_object_type: "orders", base_object_id: base_object.id, id: folder.id
      expect(response).not_to be_success
      json = JSON.parse response.body
      expect(json['errors']).to eq ["Access denied."]
    end
  end

  describe "index" do
    context "when user can view the base object" do
      before :each do
        Order.any_instance.stub(:can_view?).with(user).and_return true
        Folder.any_instance.stub(:can_view?).with(user).and_return true
        folder
      end

      it "returns a listing of the folders associated with the base object" do
        get :index, base_object_type: "orders", base_object_id: base_object.id

        expect(response).to be_success
        json = JSON.parse response.body
        expect(json).to eq({"folders" => [{"id" => folder.id, "fld_name" => "Folder Name", "fld_created_at" => folder.created_at.iso8601, "fld_created_by_username"=> user.username, "fld_created_by_fullname"=>user.full_name, "fld_created_by"=>user.id, "attachments"=>[], "comments"=>[], "groups"=>[],
          "permissions" => {"can_edit"=> false, "can_attach" => false, "can_comment" => false}
          }]})
      end
    end

    it "errors when user cannot view base object" do
      Order.any_instance.stub(:can_view?).with(user).and_return false
      get :index, base_object_type: "orders", base_object_id: base_object.id
      expect(response).not_to be_success
      json = JSON.parse response.body
      expect(json['errors']).to eq ["Access denied."] 
    end

    it "excludes folder from listing if user cannot view it" do
      Order.any_instance.stub(:can_view?).with(user).and_return true
      Folder.any_instance.stub(:can_view?).with(user).and_return false

      get :index, base_object_type: "orders", base_object_id: base_object.id

      expect(response).to be_success
      json = JSON.parse response.body
      expect(json).to eq({"folders" => []})
    end
  end


  describe "create" do
    context "when user can edit the base object" do
      before :each do
        Order.any_instance.stub(:can_attach?).with(user).and_return true
      end

      it "creates new folder instance in base object" do
        post :create, base_object_type: "orders", base_object_id: base_object.id, folder: {fld_name: "FOLDER"}
        expect(response).to be_success

        folder = Folder.first
        json = JSON.parse response.body
        expect(json).to eq({"folder" => {"id" => folder.id, "fld_name" => "FOLDER", "fld_created_at" => folder.created_at.iso8601, "fld_created_by_username"=> user.username, "fld_created_by_fullname"=>user.full_name, "fld_created_by"=>user.id, "attachments"=>[], "comments"=>[], "groups"=>[],
          "permissions" => {"can_edit"=> true, "can_attach" => true, "can_comment" => true}
          }})

        expect(base_object.entity_snapshots.length).to eq 1
      end
    end

    it "errors if user cannot edit base object" do
      Order.any_instance.stub(:can_attach?).with(user).and_return false
      post :create, base_object_type: "orders", base_object_id: base_object.id, folder: {fld_name: "FOLDER"}
      expect(response).not_to be_success
      json = JSON.parse response.body
      expect(json['errors']).to eq ["Access denied."] 
    end
  end

  describe "update" do
    context "when user can edit the base object" do
      before :each do
        Order.any_instance.stub(:can_attach?).with(user).and_return true
        Folder.any_instance.stub(:can_edit?).with(user).and_return true
      end

      it "updates a folder instance" do
        put :update, base_object_type: "orders", base_object_id: base_object.id, id: folder.id, folder: {fld_name: "FOLDER"}
        expect(response).to be_success

        folder = Folder.first
        json = JSON.parse response.body
        expect(json).to eq({"folder" => {"id" => folder.id, "fld_name" => "FOLDER", "fld_created_at" => folder.created_at.iso8601, "fld_created_by_username"=> user.username, "fld_created_by_fullname"=>user.full_name, "fld_created_by"=>user.id, "attachments"=>[], "comments"=>[], "groups"=>[],
          "permissions" => {"can_edit"=> true, "can_attach" => true, "can_comment" => true}
          }})

        expect(base_object.entity_snapshots.length).to eq 1
      end
    end

    it "errors if user cannot edit base object" do
      Order.any_instance.stub(:can_attach?).with(user).and_return false
      put :update, base_object_type: "orders", base_object_id: base_object.id, id: folder.id, folder: {fld_name: "FOLDER"}
      expect(response).not_to be_success
      json = JSON.parse response.body
      expect(json['errors']).to eq ["Access denied."] 
    end

    it "errors if user cannot folder" do
      Order.any_instance.stub(:can_attach?).with(user).and_return true
      Folder.any_instance.stub(:can_edit?).with(user).and_return false
      put :update, base_object_type: "orders", base_object_id: base_object.id, id: folder.id, folder: {fld_name: "FOLDER"}
      expect(response).not_to be_success
      json = JSON.parse response.body
      expect(json['errors']).to eq ["Access denied."] 
    end
  end

  describe "destroy" do
    context "when user can access folder" do
      before :each do
        Order.any_instance.stub(:can_attach?).with(user).and_return true
        Folder.any_instance.stub(:can_edit?).with(user).and_return true
      end

      it "deletes a folder" do
        delete :destroy, base_object_type: "orders", base_object_id: base_object.id, id: folder.id
        expect(response).to be_success
        expect(JSON.parse response.body).to eq({"ok" => "ok"})
        expect(base_object.entity_snapshots.length).to eq 1
        # It should only archive the folder, not actually destroy it
        expect(folder.reload).to be_archived
        # This is sort of testing the actual has_many setup, but we might as well check that here too.
        base_object.reload
        expect(base_object.folders.length).to eq 0
      end
    end
  end
end