require 'spec_helper'

describe Api::V1::Admin::GroupsController do
  let (:user) { Factory(:admin_user)}

  before :each do
    allow_api_user user
    use_json
  end

  describe "create" do
    it "creates a new group" do
      post :create, grp_system_code: "GROUP", grp_name: "Name", grp_description: "Description"
      group = Group.first
      expect(group).not_to be_nil
      expect(response).to be_success
      json = JSON.parse response.body
      expect(json).to eq({
        "group" => {'id' => group.id, 'grp_system_code' => "GROUP", 'grp_name' => "Name", 'grp_description' => "Description"}
      })
    end

    it "errors if user is not admin" do
      allow_api_user Factory(:user)
      post :create, grp_system_code: "GROUP", grp_name: "Name", grp_description: "Description"
      expect(response).not_to be_success
    end
  end

  describe "update" do
    let! (:group) { Group.create! system_code: "GROUP", name: "Name", description: "Description" }
    let! (:users) { group.users << user; [user] }

    it "updates a group" do
      put :update, id: group.id, grp_name: "Update", grp_description: "Upd. Desc"

      expect(response).to be_success
      json = JSON.parse response.body
      expect(json).to eq({
        "group" => {'id' => group.id, 'grp_system_code' => "GROUP", 'grp_name' => "Update", 'grp_description' => "Upd. Desc"}
      })

      group.reload
      expect(group.name).to eq "Update"
    end

    it "errors if user is not admin" do
      allow_api_user Factory(:user)
      put :update, id: group.id, grp_name: "Update", grp_description: "Upd. Desc"
      expect(response).not_to be_success
    end
  end

  describe "destroy" do
    let! (:group) { Group.create! system_code: "GROUP", name: "Name", description: "Description" }

    it "destroys a group" do
      delete :destroy, id: group.id
      expect(response).to be_success
      expect(Group.where(system_code: "GROUP").first).to be_nil
    end

    it "errors if user is not admin" do
      allow_api_user Factory(:user)
      delete :destroy, id: group.id
      expect(response).not_to be_success
    end
  end
end