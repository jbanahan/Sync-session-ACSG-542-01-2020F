require 'spec_helper'

describe UserSessionsController do
  describe 'index' do
    it "should redirect to new if user not logged in" do
      get :index
      expect(response).to redirect_to login_path
    end
    it "should redirect to root if user logged in" do
      sign_in_as Factory(:user)
      get :index
      expect(response).to redirect_to root_path
    end
  end
  describe 'new' do
    it "should redirect if user already logged in" do
      sign_in_as Factory(:user)
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
      @user = Factory(:user, :host_with_port=>"test")
      @user.update_user_password 'this is my password', 'this is my password'
    end

    it 'should allow a user to log in' do
      User.any_instance.should_receive(:on_successful_login).with request
      post :create, :user_session => {'username'=>@user.username, 'password'=>'this is my password'}
      
      expect(response).to be_redirect
      expect(response).to redirect_to root_path
      expect(cookies[:remember_me]).to be_nil
      expect(controller.current_user).not_to be_nil
    end

    it 'sets a cookie to remember the user by if user requests it' do
      post :create, :user_session => {'username'=>@user.username, 'password'=>'this is my password'}, :remember_me=>"Y"
      expect(response).to be_redirect
      expect(response).to redirect_to root_path
      expect(cookies[:remember_me]).to eq ""
    end

    it 'redirects to specified return to page' do
      session[:return_to] = "/return_to"
      post :create, :user_session => {'username'=>@user.username, 'password'=>'this is my password'}
      
      expect(response).to be_redirect
      expect(response).to redirect_to "/return_to"
    end

    it 'should fail with invalid credentials' do
      User.any_instance.should_not_receive(:on_successful_login).with request
      post :create, :user_session => {'username'=>@user.username, 'password'=>"password"} 
      expect(response).to render_template("new")
      expect(flash[:errors]).to include "Your login was not successful."
    end

    it "should allow a user to log in with via json" do
      User.any_instance.should_receive(:on_successful_login).with request
      post :create, :user_session => {'username'=>@user.username, 'password'=>'this is my password'}, :format => "json"
    
      expect(response).to be_success
      expect(response.body).to eq " "
    end

    it "should return json with errors if login failed" do
      User.any_instance.should_not_receive(:on_successful_login).with request
      post :create, :user_session => {'username'=>@user.username, 'password'=>'password'}, :format => "json"
    
      expect(response).to be_success
      expect(response.body).to eq({"errors" => ["Your login was not successful."]}.to_json)
    end
  end

  describe "create_from_omniauth" do
    before :each do
      @user = Factory(:user)
    end

    it "should sign in when user is found successfully" do
      User.should_receive(:from_omniauth).and_return(@user)
      post :create_from_omniauth, provider: "google_oauth2"

      response.should be_redirect
      controller.current_user.id.should == @user.id
      expect(response).to redirect_to root_path
    end

    it "should display an error on the login page when unsuccessful" do
      User.should_receive(:from_omniauth).and_return(@user)
      (Clearance::SuccessStatus).any_instance.stub(:success?).and_return false
      post :create_from_omniauth, provider: "google_oauth2"

      flash[:notices].should == nil
      flash[:errors].should == ["Your login was not successful."]
      response.should be_success
    end

    it "should display an error on the login page when account does not exist" do
      User.should_receive(:from_omniauth).and_return(nil)
      post :create_from_omniauth, provider: "google_oauth2"

      flash[:notices].should == nil
      flash[:errors].should == ["This account is not yet authenticated."]
      response.should be_redirect
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
