require 'spec_helper'

describe OpenChain::SlackClient do
  before :each do
    @fake_client = double('Slack::Web::Client')
    allow(OpenChain::SlackClient).to receive(:slack_client).and_return @fake_client
  end
  describe "initalize" do
    it "should get bot-api token from default location" do
      expect(File).to receive(:exist?).with("config/slack_client.yml").and_return true
      expect(YAML).to receive(:load_file).with("config/slack_client.yml").and_return({"VFITRACK_SLACK_TOKEN"=>"abc"})
      expect(described_class.new.slack_token).to eq 'abc'
    end

    it "uses provided token" do
      expect(described_class.new("token").slack_token).to eq 'token'
    end
  end

  describe "send message" do
    it "should send message if @slack_token" do
      allow(Rails.env).to receive(:production?).and_return true
      expected = {channel:'c',  text:'txt', as_user: true}
      expect(@fake_client).to receive(:chat_postMessage).with(expected)
      c = described_class.new('abc')
      c.send_message!('c','txt')
    end
    it "raises an error if no @slack_token" do
      allow(Rails.env).to receive(:production?).and_return true
      expect(@fake_client).not_to receive(:chat_postMessage)
      c = described_class.new ''
      expect{c.send_message!('c','txt')}.to raise_error "SlackClient initialization failed: No slack_token set. (Try setting up the slack_client.yml file)"
    end
    it "should prefix DEV MESSAGE: if not Rails.env.production?" do
      expected = {channel:'c',  text:'DEV MESSAGE: txt', as_user:true}
      expect(@fake_client).to receive(:chat_postMessage).with(expected)
      c = described_class.new('abc')
      c.send_message!('c','txt')
    end

    it "should not raise error for non-bang version" do
      expected = {channel:'c',  text:'DEV MESSAGE: txt', as_user:true}
      expect(@fake_client).to receive(:chat_postMessage).with(expected).and_raise('hello')
      c = described_class.new('abc')
      expect {c.send_message('c','txt')}.to_not raise_error
    end
    it "should raise error for bang version" do
      expected = {channel:'c',  text:'DEV MESSAGE: txt', as_user:true}
      expect(@fake_client).to receive(:chat_postMessage).with(expected).and_raise('hello')
      c = described_class.new('abc')
      expect {c.send_message!('c','txt')}.to raise_error
    end
  end
end