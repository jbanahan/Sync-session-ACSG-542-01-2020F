require 'spec_helper'

describe EmailAttachmentsController do
  before :each do
    @ea = Factory(:email_attachment)
  end
  
  describe "GET 'show'" do
    it "should be successful" do
      get 'show', :id => @ea.id
      response.should be_success
    end
  end

  describe "GET 'download'" do
    describe 'multiple saved email addresses' do
      it "sends file when mails are separated with comma" do
        @ea.email = "foo@example.com,bar@example.com,baz@example.com"
        @ea.save
        Attachment.any_instance.should_receive(:secure_url).and_return "http://test.com"
        get 'download', :id => @ea.id, :email => "foo@example.com"
        response.should redirect_to "http://test.com"
      end

      it "sends file when mails are separated with semicolon" do
        @ea.email = "foo@example.com;bar@example.com;baz@example.com"
        @ea.save
        Attachment.any_instance.should_receive(:secure_url).and_return "http://test.com"
        get 'download', :id => @ea.id, :email => "bar@example.com"
        response.should redirect_to "http://test.com"
      end

      it "sends file when mails are separated with mixed separators" do
        @ea.email = "foo@example.com,bar@example.com;baz@example.com"
        @ea.save
        Attachment.any_instance.should_receive(:secure_url).and_return "http://test.com"
        get 'download', :id => @ea.id, :email => "baz@example.com"
        response.should redirect_to "http://test.com"
      end

      it "sends file when mixed casing is present" do
        @ea.email = "foo@example.com,bar@example.com;baz@example.com"
        @ea.save
        Attachment.any_instance.should_receive(:secure_url).and_return "http://test.com"
        get 'download', :id => @ea.id, :email => "BaZ@Example.COM"
        response.should redirect_to "http://test.com"
      end
    end

    describe 'not registered email address' do
      it 'displays message about not registered e-mail address' do
        get 'download', :id => @ea.id, :email => 'me@example.net'
        flash[:errors].should include "Attachment is not registered for given e-mail address"
        response.should be_redirect
      end
    end
  end
end
