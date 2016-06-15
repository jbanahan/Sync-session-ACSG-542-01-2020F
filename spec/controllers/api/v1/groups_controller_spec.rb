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
end