require 'spec_helper'

describe OpenChain::GoogleAccountChecker do
  let!(:user) { Factory(:user, email: 'dummy@vandegriftinc.com', disabled: false) }

  def response_double(json_file)
    resp = double("GoogleApiResponse")
    allow(resp).to receive(:response).and_return resp
    allow(resp).to receive(:body).and_return json_file

    resp
  end

  let (:service) {
    service = instance_double(Google::Apis::AdminDirectoryV1::DirectoryService)
  }

  let (:suspended_user_response) {
    response = double("GoogleApiResponseDouble")
    user = double("GoogleApiResponseUser")
    allow(user).to receive(:suspended?).and_return true
    allow(response).to receive(:users).and_return [user]
    allow(response).to receive(:to_json).and_return '{suspended:true}'

    response
  }

  let (:missing_user_response) {
    response = double("GoogleApiResponseDouble")
    allow(response).to receive(:users).and_return []
    allow(response).to receive(:to_json).and_return '{missing:true}'

    response
  }

  let (:active_user_response) {
    response = double("GoogleApiResponseDouble")
    user = double("GoogleApiResponseUser")
    allow(user).to receive(:suspended?).and_return false
    allow(response).to receive(:users).and_return [user]
    allow(response).to receive(:to_json).and_return '{active:true}'

    response
  }

  describe "run_schedulable" do

    before :each do 
      allow(subject).to receive(:admin_directory_service).and_return service
    end

    it "does nothing for active users" do
      expect(service).to receive(:list_users).with(customer: "my_customer", domain: "vandegriftinc.com", max_results: 1, query: "email='dummy@vandegriftinc.com'").and_return active_user_response
      subject.run
      user.reload
      expect(user.disabled?).to eq false
    end

    it "strips alias information from email account" do
      user.update_attributes!(email: 'dummy+blahblah@vandegriftinc.com')
      expect(service).to receive(:list_users).with(customer: "my_customer", domain: "vandegriftinc.com", max_results: 1, query: "email='dummy@vandegriftinc.com'").and_return active_user_response
      subject.run
      user.reload
      expect(user.disabled?).to eq false
    end

    it "disables accounts that don't exist" do
      expect(service).to receive(:list_users).with(customer: "my_customer", domain: "vandegriftinc.com", max_results: 1, query: "email='dummy@vandegriftinc.com'").and_return missing_user_response
      subject.run
      user.reload
      expect(user.disabled?).to eq true

      # Also verify that an email was sent
      mail = ActionMailer::Base.deliveries.first
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["bug@vandegriftinc.com"]
      expect(mail.subject).to eq "VFI Track Account Disabled: dummy@vandegriftinc.com"
      # Just make sure the response data is included in the email body
      expect(mail.body.raw_source).to include "{missing:true}"
    end

    it "disables suspended accounts" do
      expect(service).to receive(:list_users).with(customer: "my_customer", domain: "vandegriftinc.com", max_results: 1, query: "email='dummy@vandegriftinc.com'").and_return suspended_user_response
      subject.run
      user.reload
      expect(user.disabled?).to eq true

      # Also verify that an email was sent
      mail = ActionMailer::Base.deliveries.first
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["bug@vandegriftinc.com"]
      expect(mail.subject).to eq "VFI Track Account Disabled: dummy@vandegriftinc.com"
      # Just make sure the response data is included in the email body
      expect(mail.body.raw_source).to include "{suspended:true}"
    end

  end
end