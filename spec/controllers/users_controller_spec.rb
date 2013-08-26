require 'spec_helper'

describe UsersController do
  before :each do
    @user = Factory(:user)
    activate_authlogic
    UserSession.create! @user
  end
  describe 'hide_message' do
    it "should hide message" do
      post :hide_message, :message_name=>'mn'
      @user.reload
      @user.hide_message?('mn').should be_true
      response.should be_success
      JSON.parse(response.body).should == {'OK'=>'OK'}
    end
  end
  describe 'show_bulk_upload' do
    it "should show bulk upload for admin" do
      @user.admin = true
      @user.save!
      get :show_bulk_upload, 'company_id'=>@user.company_id.to_s
      response.should be_success
    end
    it "should not show bulk upload for non-admin" do
      get :show_bulk_upload, 'company_id'=>@user.company_id.to_s
      response.should be_redirect
      flash[:errors].should have(1).message
    end
  end
  describe 'bulk_upload' do
    it "should create users from csv" do
      User.any_instance.stub(:admin?).and_return(true)
      data = "uname,joe@sample.com,Joe,Smith,js1234567\nun2,fred@sample.com,Fred,Dryer,fd654321"
      post :bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data, 'user'=>{'order_view'=>1,'email_format'=>'html'}
      response.should be_success
      JSON.parse(response.body)['count'].should == 2
      u = User.find_by_company_id_and_username @user.company_id, 'uname'
      u.email.should == 'joe@sample.com'
      u.first_name.should == 'Joe'
      u.last_name.should == 'Smith'
      u.should be_order_view
      u.should_not be_order_edit
      u.email_format.should == 'html'

      u = User.find_by_company_id_and_username @user.company_id, 'un2'
      u.email.should == 'fred@sample.com'
      u.first_name.should == 'Fred'
      u.last_name.should == 'Dryer'
      u.should be_order_view
      u.should_not be_order_edit
      u.email_format.should == 'html'

    end
    it "should show errors for some users while creating others" do
      User.any_instance.stub(:admin?).and_return(true)
      data = "uname,joe@sample.com,Joe,Smith,js1234567\nun2,f,Fred,Dryer,fd654321"
      post :bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data, 'user'=>{'order_view'=>1,'email_format'=>'html'}
      response.status.should == 400
      JSON.parse(response.body)['error'].should_not be_blank
    end
    it "should fail if user not admin" do
      User.any_instance.stub(:admin?).and_return(false)
      uc = User.all.size
      data = "uname,joe@sample.com,Joe,Smith,js1234567\nun2,fred@sample.com,Fred,Dryer,fd654321"
      post :bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data, 'user'=>{'order_view'=>1,'email_format'=>'html'}
      response.should be_redirect
      User.all.size.should == uc
    end
  end
  describe 'preview_bulk_upload' do
    it "should return json table" do
      data = "uname,joe@sample.com,Joe,Smith,js1234567\nun2,fred@sample.com,Fred,Dryer,fd654321"
      post :preview_bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data
      response.should be_success
      h = JSON.parse response.body
      h['results'].should have(2).items
      r = h['results']
      r[0].should == {'username'=>'uname','email'=>'joe@sample.com','first_name'=>'Joe','last_name'=>'Smith','password'=>'js1234567'}
      r[1].should == {'username'=>'un2','email'=>'fred@sample.com','first_name'=>'Fred','last_name'=>'Dryer','password'=>'fd654321'}
    end
    it "should return 400 with error if not valid csv" do
      data = "uname,\""
      post :preview_bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data
      response.status.should == 400
    end
    it "should return 400 with error if not right number of elements" do
      data = "uname"
      post :preview_bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data
      response.status.should == 400
    end
  end

  describe :bulk_invite do

    it "should invite multiple users" do
      @user.admin = true
      @user.save

      User.should_receive(:delay).and_return User
      User.should_receive(:send_invite_emails).with ["1", "2", "3"]
      post :bulk_invite, id: [1, 2, 3], company_id: @user.company_id

      response.should redirect_to company_users_path @user.company_id
      flash[:notices].first.should == "The user invite emails will be sent out shortly."
    end

    it "should only allow admins access" do
      @user.admin = false
      @user.save

      post :bulk_invite, id: [1, 2, 3], company_id: @user.company_id

      response.should redirect_to "/"
      flash[:errors].first.should == "Only administrators can send invites to users."
    end

    it "should verify at least one user selected" do
      @user.admin = true
      @user.save

      post :bulk_invite, company_id: @user.company_id
      response.should redirect_to company_users_path @user.company_id
      flash[:errors].first.should == "Please select at least one user."
    end
  end
end
