require 'spec_helper'

describe AttachmentArchiveSetupsController do
  before :each do 
    @admin = Factory(:admin_user)
    @user = Factory(:user)
    @c = Factory(:company)

  end
  describe "new" do
    it "should fail if user not admin" do
      sign_in_as @user
      get :new, :company_id=>@c.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end
    it "should succeed if user admin" do
      sign_in_as @admin
      get :new, :company_id=>@c.id
      expect(response).to be_success
      expect(assigns(:company)).to eq(@c)
    end
  end
  describe "edit" do
    before :each do
      @c.create_attachment_archive_setup(:start_date=>Time.now)
    end
    it "should fail if user not admin" do
      sign_in_as @user
      get :edit, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end
    it "should succeed if user admin" do
      sign_in_as @admin
      get :edit, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id
      expect(response).to be_success
      expect(assigns(:company)).to eq(@c)
    end
  end
  describe "create" do
    it "should succeed if user admin" do
      sign_in_as @admin
      target_date = Date.new(2011,12,1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq(target_date)
      expect(response).to redirect_to [@c,@c.attachment_archive_setup]
      expect(flash[:notices]).to eq(["Your setup was successfully created."])
    end
    it "should fail if company already has record" do
      sign_in_as @admin
      @c.create_attachment_archive_setup(:start_date=>Time.now)
      target_date = Date.new(2011,12,1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq(0.seconds.ago.to_date) 
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["This company already has an attachment archive setup."])
    end
    it "should fail if user not admin" do
      sign_in_as @user
      target_date = Date.new(2011,12,1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      expect(@c.attachment_archive_setup).to be_nil
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end
  end
  describe "update" do
    before :each do
      @c.create_attachment_archive_setup(:start_date=>Time.now)
    end
    it "should succeed if user is admin" do
      sign_in_as @admin
      target_date = Date.new(2011,12,1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d"), :combine_attachments=>"1", :combined_attachment_order=>"A\nB\nC"}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq target_date
      expect(@c.attachment_archive_setup.combine_attachments).to be_truthy
      expect(@c.attachment_archive_setup.combined_attachment_order).to eq "A\nB\nC"
      expect(response).to redirect_to [@c,@c.attachment_archive_setup]
      expect(flash[:notices]).to eq(["Your setup was successfully updated."])
    end
    it "should fail if user not admin" do
      sign_in_as @user
      target_date = Date.new(2011,12,1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq 0.seconds.ago.to_date 
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq ["You do not have permission to access this page."]
    end
    it "blanks the order attribute if combined attribute is not checked" do
      sign_in_as @admin
      target_date = Date.new(2011,12,1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d"), :combine_attachments=>"0", :combined_attachment_order=>"A\nB\nC"}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq target_date
      expect(@c.attachment_archive_setup.combine_attachments).to be_falsey
      expect(@c.attachment_archive_setup.combined_attachment_order).to eq ""
      expect(response).to redirect_to [@c,@c.attachment_archive_setup]
    end
  end
end
