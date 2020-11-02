describe OpenChain::EventPublisher, :event_publisher do

  subject { described_class }

  describe "check_validity" do
    it "validates that the registered class includes OpenChain::Events::EventPublisherSupport" do
      expect(subject.check_validity(OpenChain::Events::DelayedJobEventPublisher)).to eq true
    end

    it "errors if class doesn't includes OpenChain::Events::EventPublisherSupport" do
      expect { subject.check_validity Object }.to raise_error "All EventPublishers must include OpenChain::Events::EventPublisherSupport."
    end

    it "errors if class doesn't implement publish method" do
      fake_publisher = Class.new do
        include OpenChain::Events::EventPublisherSupport
      end
      expect { subject.check_validity fake_publisher }.to raise_error "All EventPublishers must respond_to 'publish'."
    end

  end

  describe "publish" do
    let (:publisher) do
      Class.new do
        def publish _message_type, _object
          nil
        end
      end.new
    end

    it "calls publish on all registered publishers" do
      expect(publisher).to receive(:publish).with("message_type", "object")
      expect(subject).to receive(:registered).and_return [publisher]

      subject.publish "message_type", "object"
    end
  end

end
