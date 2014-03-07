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
      @c.attachment_archive_setup.start_date.should == 0.seconds.ago.to_date 
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
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d"), :combine_attachments=>"1", :combined_attachment_order=>"A\nB\nC"}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq target_date
      expect(@c.attachment_archive_setup.combine_attachments).to be_true
      expect(@c.attachment_archive_setup.combined_attachment_order).to eq "A\nB\nC"
      expect(response).to redirect_to [@c,@c.attachment_archive_setup]
    end
    it "should fail if user not admin" do
      UserSession.create! @user
      target_date = Date.new(2011,12,1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq 0.seconds.ago.to_date 
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq ["You do not have permission to access this page."]
    end
    it "blanks the order attribute if combined attribute is not checked" do
      UserSession.create! @admin
      target_date = Date.new(2011,12,1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d"), :combine_attachments=>"0", :combined_attachment_order=>"A\nB\nC"}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq target_date
      expect(@c.attachment_archive_setup.combine_attachments).to be_false
      expect(@c.attachment_archive_setup.combined_attachment_order).to eq ""
      expect(response).to redirect_to [@c,@c.attachment_archive_setup]
    end
  end
end
