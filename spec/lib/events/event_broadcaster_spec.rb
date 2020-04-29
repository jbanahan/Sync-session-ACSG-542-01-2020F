describe OpenChain::Events::EventBroadcaster do

  describe "broadcast" do
    context "production_environment" do

      before :each do
        @broadcaster = described_class.new(true)
      end

      it "should create an event processor and sent an event to it" do
        expect_any_instance_of(OpenChain::Events::EventProcessor).to receive(:process_event) do |instance, e|
          expect(e.event_type).to eq(:event_type)
          expect(e.object_class).to eq("Class")
          expect(e.object_id).to eq(1)
          expect(e.event_context).to eq("Context")
        end

        @broadcaster.broadcast :event_type, "Class", 1, "Context"
      end

      it "should default context to nil" do
        expect_any_instance_of(OpenChain::Events::EventProcessor).to receive(:process_event) do |instance, e|
          expect(e.event_type).to eq(:event_type)
          expect(e.object_class).to eq("Class")
          expect(e.object_id).to eq(1)
          expect(e.event_context).to be_nil
        end

        @broadcaster.broadcast :event_type, "Class", 1
      end

      it "should rescue errors from process_event" do
        expect_any_instance_of(OpenChain::Events::EventProcessor).to receive(:process_event).and_raise "Error!"
        expect {@broadcaster.broadcast :event_type, "Class", 1}.to change(ErrorLogEntry, :count).by(1)
      end
    end

    it "doesn't broadcast events in the test environment" do
      b = described_class.new
      b.broadcast :event_type, "Class", 1

      expect(b.broadcasted_events.first.event_type).to eq :event_type
    end
  end

end
