require 'spec_helper'

describe SentEmailsController do

  let(:user) { Factory(:sys_admin_user, :company => Factory(:company, :master=>true)) }
  let(:email) { Factory(:sent_email, email_body: "content") }

  before :each do
    sign_in_as user
    email
  end

  describe "GET 'index'" do
    it "should be successful" do
      get :index
      expect(response).to be_success
    end

    it "should reject if user isn't sys admin" do
      user.sys_admin = false
      user.save!

      get :index
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end

  describe "GET 'show'" do
    it "shows an email" do
      get :show, :id => email.id
      expect(response).to be_success
      expect(assigns(:sent_email)).to eq email
    end

    it "rejects if user isn't sys admin" do
      user.sys_admin = false
      user.save!

      get :show, :id=> email.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end

  describe "body" do
    it "returns a sent email's body" do
      get :body, id: email.id
      expect(response).to be_success
      expect(response.body).to eq email.email_body
    end

    it "rejects if user is not an admin" do
      user.sys_admin = false
      user.save!

      get :body, id: email.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end
end
