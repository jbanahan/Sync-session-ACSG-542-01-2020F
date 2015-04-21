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

  describe "google_oauth2" do

    before :each do
      use_json
      @u = Factory(:user, username: "user", api_auth_token: "auth_token", email: "me@gmail.com")
    end

    it "uses an omniauth request to validate a user's access token" do
      oauth_client = double
      OmniAuth::Strategies::GoogleOauth2.any_instance.should_receive(:client).and_return oauth_client
      oauth_resp = double("OAuthResponse")
      oauth_client.should_receive(:request).with(:get, 'https://www.googleapis.com/oauth2/v3/userinfo', params: {access_token: "token"}).and_return oauth_resp
      oauth_resp.should_receive(:parsed).and_return({'email' => "me@gmail.com"})

      User.any_instance.should_receive(:on_successful_login)
      post :google_oauth2, access_token: "token"
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({"id" => @u.id, "username" => "user", "token" => "user:auth_token", "full_name" => @u.full_name})
    end

    it "returns 404 if server is not setup for google oauth logins" do
      Rails.application.config.should_receive(:respond_to?).with(:google_oauth2_api_login).and_return false

      post :google_oauth2, access_token: "token"
      expect(response.status).to eq 404
    end

    it "returns error if access_token is not present" do 
      post :google_oauth2
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)).to eq({'errors'=>["The access_token parameter was missing."]})
    end

    it "handles errors raised via oauth query" do
      oauth_client = double
      OmniAuth::Strategies::GoogleOauth2.any_instance.should_receive(:client).and_return oauth_client
      oauth_client.should_receive(:request).and_raise StandardError
      post :google_oauth2, access_token: "token"
      expect(response.status).to eq 403
    end

    it "returns forbidden if email from access_token is not linked to any user" do
      oauth_client = double
      OmniAuth::Strategies::GoogleOauth2.any_instance.should_receive(:client).and_return oauth_client
      oauth_resp = double("OAuthResponse")
      oauth_client.should_receive(:request).with(:get, 'https://www.googleapis.com/oauth2/v3/userinfo', params: {access_token: "token"}).and_return oauth_resp
      oauth_resp.should_receive(:parsed).and_return({'email' => "nobody@gmail.com"})

      post :google_oauth2, access_token: "token"
      expect(response.status).to eq 403
    end

    it "returns forbidden if user access has been disabled" do
      @u.disabled = true
      @u.save!

      oauth_client = double
      OmniAuth::Strategies::GoogleOauth2.any_instance.should_receive(:client).and_return oauth_client
      oauth_resp = double("OAuthResponse")
      oauth_client.should_receive(:request).with(:get, 'https://www.googleapis.com/oauth2/v3/userinfo', params: {access_token: "token"}).and_return oauth_resp
      oauth_resp.should_receive(:parsed).and_return({'email' => "me@gmail.com"})

      post :google_oauth2, access_token: "token"
      expect(response.status).to eq 403
    end
  end
end