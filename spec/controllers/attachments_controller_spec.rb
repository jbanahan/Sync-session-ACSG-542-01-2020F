require 'spec_helper'

describe AttachmentsController do

  describe "create" do
    let!(:file) { fixture_file_upload('/files/test.txt', 'text/plain') }
    let!(:user) { Factory(:user, first_name: "Nigel", last_name: "Tufnel", email: "nigel@stonehenge.biz") }
    let!(:prod) { Factory(:product) }

    before do
      stub_paperclip
      allow_any_instance_of(Product).to receive(:can_attach?).and_return true
      sign_in_as user
    end

    it "calls log_update and attachment_added if base object responds to those methods" do
      expect_any_instance_of(Product).to receive(:log_update).with(user)
      attachment_id = nil
      expect_any_instance_of(Product).to receive(:attachment_added) do |instance, attach|
        attachment_id = attach.id
      end
    
      expect(OpenChain::WorkflowProcessor).to receive(:async_process).with(prod)
      post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}
      expect(response).to redirect_to prod
      expect(prod.attachments.length).to eq 1
      att = prod.attachments.first
      expect(att.uploaded_by).to eq user
      expect(att.attached_file_name).to eq "test.txt"
      expect(att.id).to eq attachment_id
    end

    context "with http request" do
      it "creates an attachment" do
        expect(OpenChain::WorkflowProcessor).to receive(:async_process).with(prod)
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}
        expect(response).to redirect_to prod
        prod.reload
        expect(prod.attachments.length).to eq 1
        att = prod.attachments.first
        expect(att.uploaded_by).to eq user
        expect(att.attached_file_name).to eq "test.txt"
      end

      it "errors if no file is given" do
        post :create, attachment: {attachable_id: prod.id, attachable_type: "Product"}
        expect(response).to redirect_to request.referrer
        expect(flash[:errors]).to include "Please choose a file before uploading."
        expect(prod.attachments.length).to eq 0
      end

      it "errors if user cannot attach" do
        allow_any_instance_of(Product).to receive(:can_attach?).and_return false
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}
        expect(response).to redirect_to prod
        expect(flash[:errors]).to include "You do not have permission to attach items to this object."
        expect(prod.attachments.length).to eq 0
      end

      it "errors if attachment can't be saved" do
        allow_any_instance_of(Attachment).to receive(:save!) do |att|
          att.errors[:base] << "SOMETHING WRONG"
          false
        end
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}
        expect(response).to redirect_to prod
        expect(flash[:errors]).to include "SOMETHING WRONG"
        expect(prod.attachments.length).to eq 0
      end
    end

    context "with JSON request" do
      it "creates an attachment" do
        expect(OpenChain::WorkflowProcessor).to receive(:async_process).with(prod)
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}, :format => :json
        prod.reload
        expect(prod.attachments.length).to eq 1
        att = prod.attachments.first
        expect(att.uploaded_by).to eq user
        expect(att.attached_file_name).to eq "test.txt"

        json = JSON.parse(response.body)
        expect(json["attachments"].first["user"]["full_name"]).to eq "Nigel Tufnel"
        expect(json["attachments"].first["name"]).to eq "test.txt"
      end

      it "errors if no file is given" do
        post :create, attachment: {attachable_id: prod.id, attachable_type: "Product"}, :format=>:json
        expect(JSON.parse(response.body)).to eq ({"errors" => ["Please choose a file before uploading."]})
        expect(prod.attachments.length).to eq 0
      end

      it "errors if user cannot attach" do
        allow_any_instance_of(Product).to receive(:can_attach?).and_return false
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}, :format=>:json
        expect(JSON.parse(response.body)).to eq ({"errors" => ["You do not have permission to attach items to this object."]})
        expect(prod.attachments.length).to eq 0
      end

      it "errors if attachment can't be saved" do
        allow_any_instance_of(Attachment).to receive(:save!) do |att|
          att.errors[:base] << "SOMETHING WRONG"
          false
        end
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}, :format=>:json
        expect(JSON.parse(response.body)).to eq ({"errors" => ["SOMETHING WRONG"]})
        expect(prod.attachments.length).to eq 0
      end
    end

  end

  describe "send_email_attachable" do

    before :each do 
      @u = Factory(:user, first_name: "Nigel", last_name: "Tufnel", email: "nigel@stonehenge.biz")
      @e = Factory(:entry)
      sign_in_as @u 
    end

    it "checks that there is at least one email" do
      expect(Attachment).not_to receive(:delay)
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: "", email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: ['1','2','3'], full_name: @u.full_name, email: @u.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Please enter an email address."
    end
    
    it "checks that there are no more than 10 emails" do
      too_many_emails = []
      11.times{ |n| too_many_emails << "address#{n}@abc.com" }
      
      expect(Attachment).not_to receive(:delay)
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: too_many_emails.join(','), email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: ['1','2','3'], full_name: @u.full_name, email: @u.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Cannot accept more than 10 email addresses."
    end
    
    it "validates email addresses before sending" do
      expect(Attachment).not_to receive(:delay)
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: "john@abc.com, sue@abccom", email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: ['1','2','3'], full_name: @u.full_name, email: @u.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Please ensure all email addresses are valid."
    end

    it "checks that attachments are under 10MB" do
      att_1 = Factory(:attachment, attached_file_size: 5000000)
      att_2 = Factory(:attachment, attached_file_size: 7000000)
      expect(Attachment).not_to receive(:delay)
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: "john@abc.com, sue@abc.com", email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: [att_1.id.to_s, att_2.id.to_s], full_name: @u.full_name, email: @u.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Attachments cannot be over 10 MB."
    end

    it "sends email" do
      d = double("delay")
      expect(Attachment).to receive(:delay).and_return d
      expect(d).to receive(:email_attachments).with(to_address: "john@abc.com, sue@abc.com", email_subject: "test message", email_body: "This is a test.",
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
      expect_any_instance_of(Entry).to receive(:last_file_secure_url).and_return "http://redirect.com"
      expect_any_instance_of(Entry).to receive(:can_view?).with(user).and_return true

      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to redirect_to("http://redirect.com")
    end

    it "disallows non-sysadmin users" do
      sign_in_as Factory(:user)
      allow_any_instance_of(Entry).to receive(:can_view?).with(user).and_return true      
      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "disallows users that can't view object" do
      allow_any_instance_of(Entry).to receive(:can_view?).with(user).and_return false      
      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles objects that don't have integration files" do
      entry.update_attributes! last_file_path: nil

      allow_any_instance_of(Entry).to receive(:can_view?).with(user).and_return true      
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

  describe "download" do
    let (:secure_url) { "http://my.secure.url"}
    let (:attachment) { double(:attachment, secure_url: secure_url) }
    let (:user) { Factory(:user) }

    it "downloads an attachment via s3 redirect" do
      sign_in_as user
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return true

      get :download, id: 1
      expect(response).to redirect_to secure_url
    end

    it "directly downloads an attachment when master setup is proxying downloads" do
      sign_in_as user

      ms = double("MasterSetup")
      allow(ms).to receive(:custom_feature?).with("Attachment Mask").and_return true
      allow(MasterSetup).to receive(:get).and_return ms
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return true
      allow(attachment).to receive(:attached_file_name).and_return "file.txt"
      allow(attachment).to receive(:attached_content_type).and_return "text/plain"

      tf = double("Tempfile")
      expect(tf).to receive(:read).and_return "data"
      expect(attachment).to receive(:download_to_tempfile).and_yield tf

      get :download, id: 1
      expect(response).to be_success
      expect(response.body).to eq "data"
    end

    it "redirects if user can't access attachment" do
      sign_in_as user
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return false

      get :download, id: 1
      expect(response).to redirect_to root_path
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end
  end
end