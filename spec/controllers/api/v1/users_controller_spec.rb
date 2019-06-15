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

  describe "google_oauth2", :without_partial_double_verification do

    before :each do
      use_json
      @u = Factory(:user, username: "user", api_auth_token: "auth_token", email: "me@gmail.com")
      @config = {client_secret: "secret", client_id: "id"}
      allow(Rails.application.config).to receive(:google_oauth2_api_login).and_return @config
      allow(MasterSetup).to receive(:test_env?).and_return false
    end

    it "uses an omniauth request to validate a user's access token" do
      oauth_client = double
      expect_any_instance_of(OmniAuth::Strategies::GoogleOauth2).to receive(:client).and_return oauth_client
      oauth_resp = double("OAuthResponse")
      expect(oauth_client).to receive(:request).with(:get, 'https://www.googleapis.com/oauth2/v3/userinfo', params: {access_token: "token"}).and_return oauth_resp
      expect(oauth_resp).to receive(:parsed).and_return({'email' => "me@gmail.com"})

      expect_any_instance_of(User).to receive(:on_successful_login)
      post :google_oauth2, access_token: "token"
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({"id" => @u.id, "username" => "user", "token" => "user:auth_token", "full_name" => @u.full_name})
    end

    it "returns 404 if server is not setup for google oauth logins" do
      expect(MasterSetup).to receive(:test_env?).and_return false
      expect(Rails.application.config).to receive(:respond_to?).with(:google_oauth2_api_login).and_return false

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
      expect_any_instance_of(OmniAuth::Strategies::GoogleOauth2).to receive(:client).and_return oauth_client
      expect(oauth_client).to receive(:request).and_raise StandardError
      post :google_oauth2, access_token: "token"
      expect(response.status).to eq 403
    end

    it "returns forbidden if email from access_token is not linked to any user" do
      oauth_client = double
      expect_any_instance_of(OmniAuth::Strategies::GoogleOauth2).to receive(:client).and_return oauth_client
      oauth_resp = double("OAuthResponse")
      expect(oauth_client).to receive(:request).with(:get, 'https://www.googleapis.com/oauth2/v3/userinfo', params: {access_token: "token"}).and_return oauth_resp
      expect(oauth_resp).to receive(:parsed).and_return({'email' => "nobody@gmail.com"})

      post :google_oauth2, access_token: "token"
      expect(response.status).to eq 403
    end

    it "returns forbidden if user access has been disabled" do
      @u.disabled = true
      @u.save!

      oauth_client = double
      expect_any_instance_of(OmniAuth::Strategies::GoogleOauth2).to receive(:client).and_return oauth_client
      oauth_resp = double("OAuthResponse")
      expect(oauth_client).to receive(:request).with(:get, 'https://www.googleapis.com/oauth2/v3/userinfo', params: {access_token: "token"}).and_return oauth_resp
      expect(oauth_resp).to receive(:parsed).and_return({'email' => "me@gmail.com"})

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
        'id'=>u.id,
        'company_id'=>u.company_id,
        'department'=>u.department}}
      response_json = JSON.parse(response.body)
      # not testing every permission
      expect(response_json['user']['permissions'].size).to be > 0
      response_json['user'].delete('permissions')
      expect(response_json).to eq expected
    end
  end

  describe "enabled_users" do
    it "returns enabled users belonging to current_user's visible companies" do
      linked_co = Factory(:company, name: 'Konvenientz')
      co = Factory(:company, name: 'Acme', linked_companies: [linked_co])
      u = Factory(:user, company: co, first_name: 'Nigel', last_name: 'Tufnel', username: 'ntufnel', disabled: false)
      u2 = Factory(:user, company: linked_co, first_name: 'David', last_name: 'St. Hubbins', username: 'dsthubbins', disabled: nil)
      u3 = Factory(:user, company: linked_co, first_name: 'AAA', last_name: 'ZZZZ', username: 'AAA ZZZZ', disabled: nil)
      Factory(:user, company: linked_co, first_name: 'Derek', last_name: 'Smalls', username: 'dsmalls', disabled: true)
      allow_api_access u
      
      get :enabled_users
      expect(response).to be_success
      expected = [{'company' => 
                    {
                     'name' => 'Acme',
                     'users' => [ {
                        'first_name' => 'Nigel',
                        'id' => u.id,
                        'last_name' => 'Tufnel',
                        'full_name' => 'Nigel Tufnel'
                       } ]
                    }},
                  {'company' =>
                    {
                     'name' => 'Konvenientz',
                     'users' => [ {
                        'first_name' => 'AAA',
                        'id' => u3.id,
                        'last_name' => 'ZZZZ',
                        'full_name' => 'AAA ZZZZ'
                       },
                       {
                         'first_name' => 'David',
                         'id' => u2.id,
                         'last_name' => 'St. Hubbins',
                         'full_name' => 'David St. Hubbins'
                        }
                        ]
                    }
                   }]
      # Make sure the companies are sorted by name and the users are sorted by name
      expect(JSON.parse(response.body)).to eq expected
    end
  end

  describe "#toggle_email_new_messages" do
    it "should set email_new_messages" do
      u = Factory(:user)
      allow_api_access u
      post :toggle_email_new_messages
      expect(response).to redirect_to '/api/v1/users/me'

      u.reload
      expect(u.email_new_messages).to be_truthy
    end
    it "should unset email_new_messages" do
      u = Factory(:user)
      u.email_new_messages = true
      u.save!
      allow_api_access u
      post :toggle_email_new_messages
      expect(response).to redirect_to '/api/v1/users/me'

      u.reload
      expect(u.email_new_messages).to be_falsey
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
