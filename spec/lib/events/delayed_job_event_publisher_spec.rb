describe OpenChain::Events::DelayedJobEventPublisher do

  describe "publish" do
    subject { described_class }

    let (:object) { Order.new }
    let (:descriptor) { {event: "descriptor"} }

    it "delays processing to DelayedJobEventProcessor" do
      expect(subject).to receive(:event_descriptor).with(:order_create, object).and_return descriptor
      expect(OpenChain::Events::DelayedJobEventProcessor).to receive(:delay).and_return OpenChain::Events::DelayedJobEventProcessor
      expect(OpenChain::Events::DelayedJobEventProcessor).to receive(:process).with(descriptor)
      subject.publish :order_create, object
    end
  end
end