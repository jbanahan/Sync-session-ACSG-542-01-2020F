require 'spec_helper'

describe AttachmentsController do
  before :each do 
    @u = Factory(:user, first_name: "Nigel", last_name: "Tufnel", email: "nigel@stonehenge.biz")
    @e = Factory(:entry)
    sign_in_as @u 
  end

  describe :send_email_attachable do
    it "validates email addresses before sending" do
      Attachment.should_not_receive(:delay)
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: "john@abc.com, sue@abccom", email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: ['1','2','3'], full_name: @u.full_name, email: @u.email
      expect(response.body).to eq "Please ensure all email addresses are valid."
    end

    it "sends email" do
      d = double("delay")
      Attachment.should_receive(:delay).and_return d
      d.should_receive(:email_attachments).with(to_address: "john@abc.com, sue@abc.com", email_subject: "test message", email_body: "This is a test.",
                                                ids_to_include: ['1','2','3'], full_name: "Nigel Tufnel", email: "nigel@stonehenge.biz")
      
      post :send_email_attachable, attachable_type: @e.class.to_s, attachable_id: @e.id, to_address: "john@abc.com, sue@abc.com", email_subject: "test message", 
                                   email_body: "This is a test.", ids_to_include: ['1','2','3'], full_name: @u.full_name, email: @u.email
      expect(response.body).to eq "OK"
    end
  end

end