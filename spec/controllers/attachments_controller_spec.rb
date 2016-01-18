require 'spec_helper'

describe AttachmentsController do
  before :each do 
    @u = Factory(:user, first_name: "Nigel", last_name: "Tufnel", email: "nigel@stonehenge.biz")
    @e = Factory(:entry)
    sign_in_as @u 
  end

  describe :send_email_attachable do

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

end