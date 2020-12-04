describe UserSessionsController do
  let (:sign_in_failure) {
    "Your log in attempt was not successful.  If you do not remember your login information please use the 'Forgot your password?' link below the password box to reset your password."
  }

  describe 'index' do
    it "should redirect to new if user not logged in" do
      get :index
      expect(response).to redirect_to login_path
    end
    it "should redirect to root if user logged in" do
      sign_in_as create(:user)
      get :index
      expect(response).to redirect_to root_path
    end
  end
  describe 'new' do
    it "should redirect if user already logged in" do
      sign_in_as create(:user)
      get :new
      expect(response).to redirect_to root_path
    end
    it "should be success if user not logged in" do
      get :new
      expect(response).to be_success
    end
  end

  describe 'create' do
    before :each do
      @user = create(:user, :host_with_port=>"test")
      @user.update_user_password 'this is my password', 'this is my password'
    end

    it 'should allow a user to log in' do
      expect_any_instance_of(User).to receive(:on_successful_login).with instance_of(ActionController::TestRequest)
      post :create, params: { :user_session => {'username'=>@user.username, 'password'=>'this is my password'} }

      expect(response).to be_redirect
      expect(response).to redirect_to root_path
      expect(cookies[:remember_me]).to be_nil
      expect(controller.current_user).not_to be_nil
    end

    context "remember me" do
      before :each do
        @remember = Rails.application.config.disable_remember_me
      end
      after :each do
        Rails.application.config.disable_remember_me = @remembe
      end

      it 'sets a cookie to remember the user by if user requests it' do
        Rails.application.config.disable_remember_me = false
        post :create, :user_session => {'username'=>@user.username, 'password'=>'this is my password'}, :remember_me=>"Y"
        expect(response).to be_redirect
        expect(response).to redirect_to root_path
        expect(cookies[:remember_me]).to eq ""
      end

      it "ignores remember me if disabled" do
        Rails.application.config.disable_remember_me = true
        post :create, :user_session => {'username'=>@user.username, 'password'=>'this is my password'}, :remember_me=>"Y"
        expect(response).to be_redirect
        expect(response).to redirect_to root_path
        expect(cookies[:remember_me]).to be_nil
      end
    end

    it 'redirects to specified return to page' do
      session[:return_to] = "/return_to"
      post :create, :user_session => {'username'=>@user.username, 'password'=>'this is my password'}

      expect(response).to be_redirect
      expect(response).to redirect_to "/return_to"
    end

    it 'should fail with invalid credentials' do
      expect_any_instance_of(User).not_to receive(:on_successful_login).with request
      post :create, :user_session => {'username'=>@user.username, 'password'=>"password"}
      expect(response).to be_redirect
      expect(response).to redirect_to "/user_sessions/new"
      expect(flash[:errors]).to include sign_in_failure
    end

    it 'should respond with password locked error if password is locked' do
      # This is testing a clearance sign in guard, set up in config/initializers/clearance
      @user.failed_logins = 0
      @user.password_locked = true
      @user.save!
      @user.reload
      expect_any_instance_of(User).not_to receive(:on_successful_login).with request
      post :create, :user_session => {'username'=>@user.username, 'password'=>'this is my password'}
      expect(response).to be_redirect
      expect(response).to redirect_to "/user_sessions/new"
      expect(flash[:errors]).to include sign_in_failure
    end

    it "does not allow users with access disabled to log in" do
      # This is testing a clearance sign in guard, set up in config/initializers/clearance
      expect(User).to receive(:access_allowed?).with(an_instance_of(User)).and_return false
      post :create, :user_session => {'username'=>@user.username, 'password'=>'this is my password'}
      expect(response).to be_redirect
      expect(response).to redirect_to "/user_sessions/new"
      expect(flash[:errors]).to include sign_in_failure
    end

    it "should allow a user to log in with via json" do
      expect_any_instance_of(User).to receive(:on_successful_login).with instance_of(ActionController::TestRequest)
      post :create, params: { :user_session => {'username'=>@user.username, 'password'=>'this is my password'} }, as: :json

      expect(response).to be_success
      expect(response.body).to be_blank
    end

    it "should return json with errors if login failed" do
      expect_any_instance_of(User).not_to receive(:on_successful_login).with instance_of(ActionController::TestRequest)
      post :create, :user_session => {'username'=>@user.username, 'password'=>'password'}, :format => "json"

      expect(response).to be_success
      expect(response.body).to eq({"errors" => ["Your log in attempt was not successful"]}.to_json)
    end
  end

  describe "create_from_omniauth" do
    before :each do
      @user = create(:user)
    end

    it "should sign in when user is found successfully" do
      request.env['omniauth.auth'] = "Testing"
      expect(User).to receive(:from_omniauth).with("my-provider", "Testing").and_return(user: @user, errors: [])
      post :create_from_omniauth, {provider: "my-provider"}

      expect(response).to be_redirect
      expect(controller.current_user.id).to eq(@user.id)
      expect(response).to redirect_to root_path
    end

    it "should display an error on the login page when from_omniauth returns an error" do
      expect(User).to receive(:from_omniauth).and_return({user: nil, errors: ["This is an error"]})
      post :create_from_omniauth, provider: "my-provider"

      expect(flash[:notices]).to eq(nil)
      expect(flash[:errors]).to eq(["This is an error"])
      expect(response).to be_redirect
      expect(response).to redirect_to login_path
    end
  end

  describe "destroy" do
    it "signs out the user and removes the remember me coookie" do
      sign_in_as @user
      request.cookies[:remember_me] = ""

      delete :destroy
      expect(response.cookies[:remember_me]).to be_nil
      expect(flash[:notices]).to include "You are logged out. Thanks for visiting."
      expect(response).to redirect_to new_user_session_path
      expect(controller.current_user).to be_nil
    end
  end
end
