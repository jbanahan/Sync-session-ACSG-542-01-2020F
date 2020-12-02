describe OpenChain::Events::SqsEventPublisher do

  describe "publish" do
    subject { described_class }

    let (:object) { Order.new }
    let (:descriptor) { {event: "descriptor"} }
    let (:user) { create(:user) }
    let! (:master_setup) { stub_master_setup }

    it "delays processing to DelayedJobEventProcessor" do
      expect(User).to receive(:api_admin).and_return user
      expect(subject).to receive(:event_descriptor).with(:order_create, object).and_return descriptor
      expect(subject).to receive(:delay).and_return subject
      expect(subject).to receive(:send_to_sqs).with({
        event: "descriptor",
        api_token: user.user_auth_token,
        host: "localhost:3000"
      }.to_json)

      subject.publish :order_create, object
    end
  end

  describe "send_to_sqs" do
    subject { described_class }

    let (:secrets) do
      { sqs_event_publisher: {"queue_url" => "url_for_queue"} }
    end

    it "posts event_descriptor to sqs queue" do
      expect(MasterSetup).to receive(:secrets).and_return secrets
      expect(OpenChain::SQS).to receive(:send_json).with("url_for_queue", "descriptor_json")

      subject.send_to_sqs "descriptor_json"
    end
  end

end