require 'spec_helper'

describe FtpSessionsController do
  before :each do

    @u = Factory(:user, :admin => true, :sys_admin => true, :company => Factory(:company, :master=>true))
    sign_in_as @u
    @ftp = Factory(:ftp_session)
  end

  describe "GET 'index'" do
    it "should be successful" do
      get :index
      response.should be_success
    end

    it "should reject if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      get :index
      response.should redirect_to root_path
      flash[:errors].should have(1).message
    end
  end

  describe "GET 'show'" do
    it "should be successful" do
      get :show, :id => @ftp.id
      response.should be_success
    end

    it "should reject if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      get :show, :id=> @ftp.id
      response.should redirect_to root_path
      flash[:errors].should have(1).message
    end
  end

  describe "GET 'download'" do
    it "should be successful" do
      get :download, :id => @ftp.id
      response.should be_success
    end

    it "should reject if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      get :download, :id=> @ftp.id
      response.should redirect_to root_path
      flash[:errors].should have(1).message
    end
  end
end
