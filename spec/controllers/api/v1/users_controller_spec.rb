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
      @config = {client_secret: "secret", client_id: "id"}
      Rails.application.config.stub(:google_oauth2_api_login).and_return @config
      described_class.any_instance.stub(:test?).and_return false
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
      described_class.any_instance.should_receive(:test?).and_return false
      Rails.application.config.should_receive(:respond_to?).with(:google_oauth2_api_login).and_return false

      post :google_oauth2, access_token: "token"
      expect(response.status).to eq 404
    end

    it "returns 404 if client_id is not setup" do 
      @config.delete :client_id
      post :google_oauth2
      expect(response.status).to eq 404
    end

    it "returns 404 if client_secret is not setup" do 
      @config.delete :client_secret
      post :google_oauth2
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

  describe "#me" do
    it "should get my user profile" do
      u = Factory(:user,
        first_name:'Joe',
        last_name:'User',
        username:'uname',
        email:'j@sample.com',
        email_new_messages:true)
      allow_api_access u

      get :me

      expect(response).to be_success
      expected = {'user'=>{
        'username'=>'uname',
        'full_name'=>u.full_name,
        'first_name'=>u.first_name,
        'last_name'=>u.last_name,
        'email'=>'j@sample.com',
        'email_new_messages'=>true,
        'id'=>u.id}}
    end
  end

  describe "#toggle_email_new_messages" do
    it "should set email_new_messages" do
      u = Factory(:user)
      allow_api_access u
      post :toggle_email_new_messages
      expect(response).to redirect_to '/api/v1/users/me'

      u.reload
      expect(u.email_new_messages).to be_true
    end
    it "should unset email_new_messages" do
      u = Factory(:user)
      u.email_new_messages = true
      u.save!
      allow_api_access u
      post :toggle_email_new_messages
      expect(response).to redirect_to '/api/v1/users/me'
      
      u.reload
      expect(u.email_new_messages).to be_false
    end
  end

  describe "change_my_password" do
    let (:user) { Factory(:user) }

    it "allows user to change their password" do
      allow_api_access(user)
      post :change_my_password, password: "TEST123"

      expect(response).to be_success
      expected = {"ok"=>"ok"}
      expect(JSON.parse(response.body)).to eq expected
    end

    it "returns errors" do
      allow_api_access(user)
      post :change_my_password
      expect(response.status).to eq 406
      expect(response.body).to eq({errors: ["Password cannot be blank."]}.to_json)
    end
  end
end