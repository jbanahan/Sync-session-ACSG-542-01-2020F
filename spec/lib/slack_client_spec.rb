require 'spec_helper'

describe OpenChain::SlackClient do
  before :each do
    @fake_client = double('Slack::Web::Client')
    Slack::Web::Client.stub(:new).and_return(@fake_client)
  end
  describe :initalize do
    it "should get bot-api token from ENV['VFITRACK_SLACK_TOKEN']" do
      old_token = ENV['VFITRACK_SLACK_TOKEN']
      begin
        ENV['VFITRACK_SLACK_TOKEN'] = 'abc'
        expect(described_class.new.slack_token).to eq 'abc'
      ensure
        ENV['VFITRACK_SLACK_TOKEN'] = old_token
      end
    end
    it "should raise exception if no token and Rails.env.production?" do
      Rails.env.stub(:production?).and_return true
      expect {described_class.new(nil)}.to raise_error /slack_token/
    end
    it "should not raise error if not production" do
      expect {described_class.new(nil)}.to_not raise_error
    end
  end

  describe "send message" do
    it "should send message if @slack_token" do
      Rails.env.stub(:production?).and_return true
      expected = {channel:'c',  text:'txt', as_user: true}
      @fake_client.should_receive(:chat_postMessage).with(expected)
      c = described_class.new('abc')
      c.send_message('c','txt')
    end
    it "should do nothing if no @slack_token" do
      @fake_client.should_not_receive(:chat_postMessage)
      c = described_class.new
      c.send_message('c','txt')
    end
    it "should prefix DEV MESSAGE: if not Rails.env.production?" do
      expected = {channel:'c',  text:'DEV MESSAGE: txt', as_user:true}
      @fake_client.should_receive(:chat_postMessage).with(expected)
      c = described_class.new('abc')
      c.send_message('c','txt')
    end
  end
end