describe OpenChain::SlackClient do

  let (:slack_client) { instance_double(Slack::Web::Client) }

  before :each do
    allow(subject).to receive(:slack_client).and_return slack_client
  end

  describe "send message!" do
    context "in production env" do
      before :each do 
        allow(MasterSetup).to receive(:production_env?).and_return true
      end

      context "with slack enabled" do
        before :each do 
          allow(subject.class).to receive(:slack_configured?).and_return true
        end

        it "should send message if configured" do
          expected = {channel:'c',  text:'txt', as_user: true}
          expect(slack_client).to receive(:chat_postMessage).with(expected)
          subject.send_message!('c','txt')
        end
      end

      it "raises an error if slack is not configured" do
        allow(subject.class).to receive(:slack_configured?).and_return false
        expect { subject.send_message!('c','txt') }.to raise_error "A Slack api_key has not been configured in secrets.yml"
      end
    end

    context "not in production env" do
      before :each do 
        allow(MasterSetup).to receive(:production_env?).and_return false
      end

      context "with slack enabled" do
        before :each do 
          allow(subject.class).to receive(:slack_configured?).and_return true
        end

        it "should prefix message with DEV MESSAGE" do
          expected = {channel:'c',  text:'DEV MESSAGE: txt', as_user:true}
          expect(slack_client).to receive(:chat_postMessage).with(expected)
          subject.send_message!('c','txt')
        end
      end
    end
  end

  describe "send_message" do 
    it "swallows errors raised by ! version of method" do
      expect(subject).to receive(:send_message!).with("channel", "text", {opts: true}).and_raise "error"
      subject.send_message("channel", "text", {opts: true})
    end
  end
end
