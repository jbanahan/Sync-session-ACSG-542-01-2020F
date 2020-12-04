describe Api::V1::Admin::GroupsController do
  let (:user) { create(:admin_user)}

  before :each do
    allow_api_user user
    use_json
  end

  describe "create" do
    it "creates a new group" do
      post :create, grp_system_code: "GROUP", grp_name: "Name", grp_description: "Description", :include=>'users', users: [user.id]
      group = Group.first
      expect(group).not_to be_nil
      expect(response).to be_success
      json = JSON.parse response.body
      g = json['group']
      expect(g['id']).to eq(group.id)
      expect(g['grp_system_code']).to eq "GROUP"
      expect(g['grp_description']).to eq "Description"
      expect(g['grp_unique_identifier']).to eq "#{group.id}-Name"
      expect(g['users'].first['id']).to eq user.id
    end

    it "errors if user is not admin" do
      allow_api_user create(:user)
      post :create, grp_system_code: "GROUP", grp_name: "Name", grp_description: "Description"
      expect(response).not_to be_success
    end
  end

  describe "update" do
    let!(:group) { Group.create! system_code: "GROUP", name: "Name", description: "Description" }
    let!(:users) { group.users << user; [user] }

    it "updates a group" do
      user2 = create(:user)
      put :update, params: { id: group.id, grp_name: "Update", grp_description: "Upd. Desc", include: "users", users: [user2.id] }

      expect(response).to be_success
      json = JSON.parse response.body
      g = json['group']
      expect(g['id']).to eq(group.id)
      expect(g['grp_name']).to eq("Update")
      expect(g['grp_system_code']).to eq "GROUP"
      expect(g['grp_description']).to eq "Upd. Desc"
      expect(g['grp_unique_identifier']).to eq "#{group.id}-Update"
      expect(g['users'].first['id']).to eq user2.id

      group.reload
      expect(group.name).to eq "Update"
    end

    it "clears users" do
      put :update, params: { id: group.id, grp_name: "Update", grp_description: "Upd. Desc", include: "users", users: "" }

      expect(response).to be_success
      json = JSON.parse response.body
      g = json['group']
      expect(g['users']).to be_empty
    end

    it "errors if user is not admin" do
      allow_api_user create(:user)
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
      allow_api_user create(:user)
      delete :destroy, id: group.id
      expect(response).not_to be_success
    end
  end
end