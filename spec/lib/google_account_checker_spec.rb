require 'spec_helper'
require 'google/api_client'

describe OpenChain::GoogleAccountChecker do
  let!(:user) { Factory(:user, email: 'dummy@vandegriftinc.com', disabled: false) }

  describe "run_schedulable" do
    it 'strips off a plus sign and anything after' do
      json_file = File.read('spec/fixtures/files/google_account_checker/user_search_active.json')
      user.update_attributes!(email: 'dummy+blahblah@vandegriftinc.com')
      user.reload
      allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
      expect_any_instance_of(Google::APIClient).to receive(:execute).with(anything, {userKey: 'dummy@vandegriftinc.com'})
      OpenChain::GoogleAccountChecker.run_schedulable({})
    end

    it 'does not raise an error on a 400 error code' do
      json_file = File.read('spec/fixtures/files/google_account_checker/user_search_user_key.json')
      allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
      expect { OpenChain::GoogleAccountChecker.run_schedulable({}) }.not_to raise_error
    end

    it 'raises an error if anything other than a 404 or 400' do
      json_file = File.read('spec/fixtures/files/google_account_checker/user_search_error.json')
      allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
      expect { OpenChain::GoogleAccountChecker.run_schedulable({}) }.to raise_error(RuntimeError, "Resource Not Found: userKey")
    end

    it 'suspends users who are not found' do
      json_file = File.read('spec/fixtures/files/google_account_checker/user_search_404.json')
      allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
      OpenChain::GoogleAccountChecker.run_schedulable({})
      user.reload
      expect(user.disabled).to eql(true)
    end

    it 'suspends users who are suspended in Google Directory' do
      json_file = File.read('spec/fixtures/files/google_account_checker/user_search_inactive.json')
      allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
      OpenChain::GoogleAccountChecker.run_schedulable({})
      user.reload
      expect(user.disabled).to eql(true)
    end

    it 'does not suspend users who are not suspended in Google Directory' do
      json_file = File.read('spec/fixtures/files/google_account_checker/user_search_active.json')
      allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
      OpenChain::GoogleAccountChecker.run_schedulable({})
      user.reload
      expect(user.disabled).to eql(false)
    end

    it "ignores users that are already disabled" do
      # Just make sure the client is not used and that'll be enough to prove we didn't check disabled users
      user.disabled = true
      user.save!
      client = instance_double("Google::APIClient")
      expect_any_instance_of(described_class).to receive(:get_client).and_return client
      expect(client).not_to receive(:execute)
      allow(client).to receive(:discovered_api)
      described_class.run_schedulable
    end

    it "retries execute failure 3 times" do
      expect_any_instance_of(described_class).to receive(:sleep).with(1).exactly(3).times
      client = instance_double("Google::APIClient")
      api = double("Api")
      expect_any_instance_of(described_class).to receive(:get_api).and_return api
      allow(api).to receive(:users).and_return api
      allow(api).to receive(:get)
      expect_any_instance_of(described_class).to receive(:get_client).and_return client
      expect(client).to receive(:execute).exactly(4).times.and_raise "Error!"

      expect { described_class.run_schedulable }.to raise_error "Error!"

    end
  end
end