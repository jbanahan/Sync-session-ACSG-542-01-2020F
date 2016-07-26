require 'spec_helper'

describe Api::V1::GroupsController do
  let (:user) { Factory(:user) }
  let (:group) { Group.create! system_code: "GROUP", name: "Name", description: "Description" }

  before :each do
    allow_api_user user
    use_json
  end

  describe "index" do
    
    before :each do
      group.users << user
    end

    it "returns all groups" do
      get :index
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json).to eq({
        "groups" => [
          {'id' => group.id, 'grp_system_code' => "GROUP", 'grp_name' => "Name", 'grp_description' => "Description"}
        ]
      })
    end

    it "returns user fields if requested" do
      get :index, include: "users"
      expect(response).to be_success
      json = JSON.parse(response.body)
      users = json['groups'].first['users']
      expect(users.length).to eq 1
      # Just check that there's a user field in here we expect
      expect(users.first['id']).to eq user.id
    end
  end

  describe "show" do
    before :each do 
      group.users << user
    end

    it "returns group" do
      get :show, id: group.id

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json).to eq({
        "group" => {'id' => group.id, 'grp_system_code' => "GROUP", 'grp_name' => "Name", 'grp_description' => "Description"}
      })
    end

    it "returns user fields if requested" do
      get :show, id: group.id, include: "users"

      expect(response).to be_success
      json = JSON.parse(response.body)
      users = json['group']['users']
      expect(users.length).to eq 1
      # Just check that there's a user field in here we expect
      expect(users.first['id']).to eq user.id
    end

    it "returns error on missing group" do
      get :show, id: 0

      expect(response.status).to eq 404
    end
  end

  describe "add_to_object" do
    
    it "adds group to specified object" do
      post :add_to_object, base_object_type: "users", base_object_id: user.id, id: group.id
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({"ok"=>"ok"})

      user.reload
      expect(user.groups).to include(group)
    end

    it "fails if user cannot edit specified object" do
      User.any_instance.should_receive(:can_edit?).and_return false
      post :add_to_object, base_object_type: "users", base_object_id: user.id, id: group.id
      expect(response).not_to be_success
      user.reload
      expect(user.groups).not_to include(group)
    end

    it "fails if object does not respond to groups" do
      order = Factory(:order)
      Order.any_instance.should_receive(:can_edit?).and_return true
      post :add_to_object, base_object_type: "orders", base_object_id: order.id, id: group.id
      expect(response).not_to be_success
    end
  end
end