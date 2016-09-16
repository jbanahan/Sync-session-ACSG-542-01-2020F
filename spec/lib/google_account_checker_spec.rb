require 'spec_helper'
require 'google/api_client'

describe OpenChain::GoogleAccountChecker do
  before do
    @user = Factory(:user, email: 'dummy@vandegriftinc.com', disabled: false)
  end

  it 'strips off a plus sign and anything after' do
    json_file = File.read('spec/fixtures/files/google_account_checker/user_search_active.json')
    @user.update_attribute(:email, 'dummy+dummy@vandegriftinc.com')
    @user.reload
    allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
    expect_any_instance_of(Google::APIClient).to receive(:execute).with(anything, {userKey: 'dummy@vandegriftinc.com'})
    OpenChain::GoogleAccountChecker.run_schedulable({})
  end

  it 'does not raise an error on a 400 error code' do
    json_file = File.read('spec/fixtures/files/google_account_checker/user_search_user_key.json')
    allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
    expect { OpenChain::GoogleAccountChecker.run_schedulable({}) }.to_not raise_error(RuntimeError, "Resource Not Found: userKey")
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
    @user.reload
    expect(@user.disabled).to eql(true)
  end

  it 'suspends users who are suspended in Google Directory' do
    json_file = File.read('spec/fixtures/files/google_account_checker/user_search_inactive.json')
    allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
    OpenChain::GoogleAccountChecker.run_schedulable({})
    @user.reload
    expect(@user.disabled).to eql(true)
  end

  it 'does not suspend users who are not suspended in Google Directory' do
    json_file = File.read('spec/fixtures/files/google_account_checker/user_search_active.json')
    allow_any_instance_of(Google::APIClient).to receive_message_chain(:execute, :response, :body).and_return(json_file)
    OpenChain::GoogleAccountChecker.run_schedulable({})
    @user.reload
    expect(@user.disabled).to eql(false)
  end
end