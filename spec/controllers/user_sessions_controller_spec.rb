require 'spec_helper'

describe UserSessionsController do
  before :each do
    activate_authlogic
  end
  describe 'index' do
    it "should redirect to new if user not logged in" do
      get :index
      response.should redirect_to new_user_session_path
    end
    it "should redirect to root if user logged in" do
      UserSession.create! Factory(:user)
      get :index
      response.should redirect_to root_path
    end
  end
  describe 'new' do
    it "should redirect if user already logged in" do
      UserSession.create! Factory(:user)
      get :new
      response.should redirect_to root_path
    end
    it "should be success if user not logged in" do
      get :new
      response.should be_success
    end
  end

  describe 'create' do
    before :each do
      UserSession.stub(:find).and_return nil
      @user = Factory(:user, :host_with_port=>"test")
    end

    it 'should allow a user to log in' do
      History.should_receive(:create).with({:history_type=>'login', :user_id=> @user.id, :company_id=> @user.company_id})
      session = double()
      session.stub(:save).and_return true
      session.stub(:user).and_return @user

      UserSession.stub(:new).with({'username'=>@user.username, 'password'=>"password"}).and_return(session)
      post :create, :user_session => {'username'=>@user.username, 'password'=>"password"}
      
      response.should redirect_to root_path
      assigns["user_session"].should == session
    end

    it 'should fail with invalid credentials' do
      session = double();
      session.stub(:save).and_return false
      UserSession.stub(:new).with({'username'=>@user.username, 'password'=>"password"}).and_return(session)
      UserSessionsController.any_instance.should_receive(:errors_to_flash).with(session, {:now => true})
      post :create, :user_session => {'username'=>@user.username, 'password'=>"password"} 

      response.should render_template("new")
    end

    it "should allow a user to log in with via json" do
      History.should_receive(:create).with({:history_type=>'login', :user_id=> @user.id, :company_id=> @user.company_id})
      session = double()
      session.stub(:save).and_return true
      session.stub(:user).and_return @user

      UserSession.stub(:new).with({'username'=>@user.username, 'password'=>"password"}).and_return(session)
      post :create, :user_session => {'username'=>@user.username, 'password'=>"password"}, :format => "json"
    
      response.should be_success
      response.body.should == " "
    end

    it "should return json with errors if login failed" do
      session = double();
      errors = double();
      session.stub(:save).and_return false
      session.stub(:errors).and_return errors
      errors.stub(:full_messages).and_return ["Test"]
      UserSession.stub(:new).with({'username'=>@user.username, 'password'=>"password"}).and_return(session)
      
      post :create, :user_session => {'username'=>@user.username, 'password'=>"password"}, :format => "json"
    
      response.should be_success
      response.body.should == {"errors" => ["Test"]}.to_json
    end
  end
end
