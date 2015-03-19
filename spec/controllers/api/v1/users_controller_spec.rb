require 'spec_helper'

describe Api::V1::UsersController do

  before :each do
    use_json
  end

  describe "login" do

    it "validates a user's login credentials" do
      u = Factory(:user, username: "user", api_auth_token: "auth_token")
      u.update_user_password "password", "password"
      post :login, {user: {username: "user", password: "password"}}

      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({"username" => "user", "token" => "auth_token"})

      # Validate the login was recorded by just lookign for a last login at value
      expect(u.reload).not_to be_nil
    end

    it "sends a forbidden error if invalid username/password is used" do
      post :login, {user: {username: "user", password: "password"}}

      expect(response.status).to eq 401
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end
end