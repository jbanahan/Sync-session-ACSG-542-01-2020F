describe Api::V1::Admin::UsersController do
  describe "add_templates" do
    it "should create new search setups based on the template" do
      allow_api_access Factory(:admin_user)
      u = Factory(:user)
      st = SearchTemplate.create!(name:'x',search_json:"{'a':'b'}")
      expect_any_instance_of(SearchTemplate).to receive(:add_to_user!).with(u)
      post :add_templates, id: u.id, template_ids: [st.id.to_s]
      expect(response).to be_success
    end
  end

  describe "change_user_password" do
    let (:admin_user) { Factory(:admin_user) }
    let (:user) { u = Factory(:user); u.update_user_password("TEST123", "TEST123"); u}

    before :each do
      allow_api_access(admin_user)
    end

    it "allows an admin to update user passwords" do
      post :change_user_password, id: user.id, password: "TEST345"

      expect(response).to be_success
      expect(response.body).to eq ""
    end

    it "returns errors to user" do
      expect(User).to receive(:where).and_return(User)
      expect(User).to receive(:first).and_return user
      expect(user).to receive(:update_user_password) do |password, pw2|
        user.errors[:password] = "is invalid"
        false
      end

      post :change_user_password, id: user.id, password: "fail"
      expect(response).not_to be_success
      expect(response.body).to eq({errors: ["Password is invalid"]}.to_json)
    end

  end
end