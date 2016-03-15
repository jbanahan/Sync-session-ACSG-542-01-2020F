require 'spec_helper'

describe AttachmentsController do

  describe :send_email_attachable do

    before :each do 
      @u = Factory(:user, first_name: "Nigel", last_name: "Tufnel", email: "nigel@stonehenge.biz")
      @e = Factory(:entry)
      sign_in_as @u 
    end

    it "checks that there is at least one email" do
      Attachment.should_not_receive(:delay)
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: "", email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: ['1','2','3'], full_name: @u.full_name, email: @u.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Please enter an email address."
    end
    
    it "checks that there are no more than 10 emails" do
      too_many_emails = []
      11.times{ |n| too_many_emails << "address#{n}@abc.com" }
      
      Attachment.should_not_receive(:delay)
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: too_many_emails.join(','), email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: ['1','2','3'], full_name: @u.full_name, email: @u.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Cannot accept more than 10 email addresses."
    end
    
    it "validates email addresses before sending" do
      Attachment.should_not_receive(:delay)
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: "john@abc.com, sue@abccom", email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: ['1','2','3'], full_name: @u.full_name, email: @u.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Please ensure all email addresses are valid."
    end

    it "checks that attachments are under 10MB" do
      att_1 = Factory(:attachment, attached_file_size: 5000000)
      att_2 = Factory(:attachment, attached_file_size: 7000000)
      Attachment.should_not_receive(:delay)
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: "john@abc.com, sue@abc.com", email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: [att_1.id.to_s, att_2.id.to_s], full_name: @u.full_name, email: @u.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Attachments cannot be over 10 MB."
    end

    it "sends email" do
      d = double("delay")
      Attachment.should_receive(:delay).and_return d
      d.should_receive(:email_attachments).with(to_address: "john@abc.com, sue@abc.com", email_subject: "test message", email_body: "This is a test.",
                                                ids_to_include: ['1','2','3'], full_name: "Nigel Tufnel", email: "nigel@stonehenge.biz")
      
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: "john@abc.com, sue@abc.com", email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: ['1','2','3'], full_name: @u.full_name, email: @u.email
      expect(response.status).to eq 200
      expect(response.body).to eq({ok: "OK"}.to_json)
    end
  end

  describe "download_last_integration_file" do
    let (:user) { Factory(:sys_admin_user) }
    let (:entry) { Factory(:entry, last_file_path: "path/to/file.json", last_file_bucket: "test") }
    
    before :each do 
      sign_in_as user
    end

    it "allows sysadmin to download integration file" do
      Entry.any_instance.should_receive(:last_file_secure_url).and_return "http://redirect.com"
      Entry.any_instance.should_receive(:can_view?).with(user).and_return true

      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to redirect_to("http://redirect.com")
    end

    it "disallows non-sysadmin users" do
      sign_in_as Factory(:user)
      Entry.any_instance.stub(:can_view?).with(user).and_return true      
      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "disallows users that can't view object" do
      Entry.any_instance.stub(:can_view?).with(user).and_return false      
      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles objects that don't have integration files" do
      entry.update_attributes! last_file_path: nil

      Entry.any_instance.stub(:can_view?).with(user).and_return true      
      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles classes that don't utilize integration files" do
      product = Factory(:product)
      get :download_last_integration_file, {attachable_type: "product", attachable_id: product.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles classes that don't exist" do
      get :download_last_integration_file, {attachable_type: "notarealclass", attachable_id: 1}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles classes that exist but aren't activerecord objects" do
      get :download_last_integration_file, {attachable_type: "String", attachable_id: 1}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end
  end
end