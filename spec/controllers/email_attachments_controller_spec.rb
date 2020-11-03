describe EmailAttachmentsController do
  let(:email_attachment) { Factory(:email_attachment) }

  describe "GET 'show'" do
    it "is successful" do
      get 'show', id: email_attachment.id
      expect(response).to be_success
    end
  end

  describe "GET 'download'" do
    describe 'multiple saved email addresses' do
      it "sends file when mails are separated with comma" do
        email_attachment.email = "foo@example.com,bar@example.com,baz@example.com"
        email_attachment.save
        expect_any_instance_of(Attachment).to receive(:secure_url).and_return "http://test.com"
        get 'download', id: email_attachment.id, email: "foo@example.com"
        expect(response).to redirect_to "http://test.com"
      end

      it "sends file when mails are separated with semicolon" do
        email_attachment.email = "foo@example.com;bar@example.com;baz@example.com"
        email_attachment.save
        expect_any_instance_of(Attachment).to receive(:secure_url).and_return "http://test.com"
        get 'download', id: email_attachment.id, email: "bar@example.com"
        expect(response).to redirect_to "http://test.com"
      end

      it "sends file when mails are separated with mixed separators" do
        email_attachment.email = "foo@example.com,bar@example.com;baz@example.com"
        email_attachment.save
        expect_any_instance_of(Attachment).to receive(:secure_url).and_return "http://test.com"
        get 'download', id: email_attachment.id, email: "baz@example.com"
        expect(response).to redirect_to "http://test.com"
      end

      it "sends file when mixed casing is present" do
        email_attachment.email = "foo@example.com,bar@example.com;baz@example.com"
        email_attachment.save
        expect_any_instance_of(Attachment).to receive(:secure_url).and_return "http://test.com"
        get 'download', id: email_attachment.id, email: "BaZ@Example.COM"
        expect(response).to redirect_to "http://test.com"
      end
    end

    describe 'not registered email address' do
      it 'displays message about not registered e-mail address' do
        get 'download', id: email_attachment.id, email: 'me@example.net'
        expect(flash[:errors]).to include "Attachment is not registered for given e-mail address"
        expect(response).to be_redirect
      end
    end
  end
end
