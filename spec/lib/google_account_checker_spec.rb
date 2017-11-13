require 'spec_helper'

describe OpenChain::GoogleAccountChecker do
  let!(:user) { Factory(:user, username: "user1", email: 'dummy@vandegriftinc.com', disabled: false) }

  let!(:user_list) {
    Set.new ["dummy@vandegriftinc.com"]
  }

  describe "run_schedulable" do

    before :each do 
      allow(subject).to receive(:google_user_list).and_return user_list
    end

    it "does nothing for active users" do
      subject.run
      user.reload
      expect(user.disabled?).to eq false
    end

    it "handles different casing in email addresses" do
      user.update_attributes! email: "DuMmY@VandegriftInc.com"
      subject.run
      user.reload
      expect(user.disabled?).to eq false
    end

    it "strips alias information from email account" do
      user.update_attributes!(email: 'dummy+blahblah@vandegriftinc.com')
      subject.run
      user.reload
      expect(user.disabled?).to eq false
    end

    it "disables accounts that are missing from the google response" do
      user_list.clear
      subject.run
      user.reload
      expect(user.disabled?).to eq true

      # Also verify that an email was sent
      mail = ActionMailer::Base.deliveries.first
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["bug@vandegriftinc.com"]
      expect(mail.subject).to eq "VFI Track Account Disabled"
      # Just make sure the response data is included in the email body
      expect(mail.body.raw_source).to include "<li>user1 - dummy@vandegriftinc.com</li>"
    end
  end
end