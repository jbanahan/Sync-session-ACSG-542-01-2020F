require 'spec_helper'

describe SentEmailsController do

  before :each do
    @u = Factory(:sys_admin_user, :company => Factory(:company, :master=>true))
    sign_in_as @u
    @sent_email = Factory(:sent_email)
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
      get :show, :id => @sent_email.id
      response.should be_success
    end

    it "should reject if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      get :show, :id=> @sent_email.id
      response.should redirect_to root_path
      flash[:errors].should have(1).message
    end
  end
end


