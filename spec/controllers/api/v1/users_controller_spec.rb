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
      expect(JSON.parse(response.body)).to eq({"id" => u.id, "username" => "user", "token" => "user:auth_token", "full_name" => u.full_name})

      # Validate the login was recorded by just lookign for a last login at value
      expect(u.reload).not_to be_nil
    end

    it "sends a forbidden error if invalid username/password is used" do
      post :login, {user: {username: "user", password: "password"}}

      expect(response.status).to eq 403
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end

    it "generates an authtoken for users without one" do
      u = Factory(:user, username: "user")
      u.update_user_password "password", "password"
      post :login, {user: {username: "user", password: "password"}}

      expect(response).to be_success
      u.reload
      expect(u.api_auth_token).not_to be_blank
      expect(JSON.parse(response.body)["token"]).to eq "#{u.username}:#{u.api_auth_token}"
    end
  end
end