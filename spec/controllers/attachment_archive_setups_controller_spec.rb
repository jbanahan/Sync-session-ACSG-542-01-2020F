require 'spec_helper'

describe AttachmentArchiveSetupsController do
  before :each do 
    @admin = Factory(:admin_user)
    @user = Factory(:user)
    @c = Factory(:company)
    activate_authlogic
  end
  describe "new" do
    it "should fail if user not admin" do
      UserSession.create! @user
      get :new, :company_id=>@c.id
      response.should redirect_to request.referrer
      flash[:errors].should == ["You do not have permission to access this page."]
    end
    it "should succeed if user admin" do
      UserSession.create! @admin
      get :new, :company_id=>@c.id
      response.should be_success
      assigns(:company).should == @c
    end
  end
  describe "edit" do
    before :each do
      @c.create_attachment_archive_setup(:start_date=>Time.now)
    end
    it "should fail if user not admin" do
      UserSession.create! @user
      get :edit, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id
      response.should redirect_to request.referrer
      flash[:errors].should == ["You do not have permission to access this page."]
    end
    it "should succeed if user admin" do
      UserSession.create! @admin
      get :edit, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id
      response.should be_success
      assigns(:company).should == @c
    end
  end
  describe "create" do
    it "should succeed if user admin" do
      UserSession.create! @admin
      target_date = Date.new(2011,12,1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      @c.attachment_archive_setup.start_date.should == target_date
      response.should redirect_to [@c,@c.attachment_archive_setup]
    end
    it "should fail if company already has record" do
      UserSession.create! @admin
      @c.create_attachment_archive_setup(:start_date=>Time.now)
      target_date = Date.new(2011,12,1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      @c.attachment_archive_setup.start_date.should == Date.new(Time.now.year,Time.now.month,Time.now.day)
      response.should redirect_to request.referrer
      flash[:errors].should == ["This company already has an attachment archive setup."]
    end
    it "should fail if user not admin" do
      UserSession.create! @user
      target_date = Date.new(2011,12,1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      @c.attachment_archive_setup.should be_nil
      response.should redirect_to request.referrer
      flash[:errors].should == ["You do not have permission to access this page."]
    end
  end
  describe "update" do
    before :each do
      @c.create_attachment_archive_setup(:start_date=>Time.now)
    end
    it "should succeed if user is admin" do
      UserSession.create! @admin
      target_date = Date.new(2011,12,1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      @c.attachment_archive_setup.start_date.should == target_date
      response.should redirect_to [@c,@c.attachment_archive_setup]
    end
    it "should fail if user not admin" do
      UserSession.create! @user
      target_date = Date.new(2011,12,1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      @c.attachment_archive_setup.start_date.should == Date.new(Time.now.year,Time.now.month,Time.now.day)
      response.should redirect_to request.referrer
      flash[:errors].should == ["You do not have permission to access this page."]
    end
  end
end
