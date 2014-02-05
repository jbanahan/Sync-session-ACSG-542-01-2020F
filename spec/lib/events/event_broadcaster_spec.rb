require "spec_helper"

describe OpenChain::Events::EventBroadcaster do

  describe :broadcast do
    context :production_environment do

      before :each do 
        @broadcaster = described_class.new(true)
      end
    
      it "should create an event processor and sent an event to it" do
        OpenChain::Events::EventProcessor.any_instance.should_receive(:process_event) do |e|
          e.event_type.should == :event_type
          e.object_class.should == "Class"
          e.object_id.should == 1
          e.event_context.should == "Context"
        end

        @broadcaster.broadcast :event_type, "Class", 1, "Context"
      end

      it "should default context to nil" do
        OpenChain::Events::EventProcessor.any_instance.should_receive(:process_event) do |e|
          e.event_type.should == :event_type
          e.object_class.should == "Class"
          e.object_id.should == 1
          e.event_context.should be_nil
        end

        @broadcaster.broadcast :event_type, "Class", 1
      end

      it "should rescue errors from process_event" do
        OpenChain::Events::EventProcessor.any_instance.should_receive(:process_event).and_raise "Error!"
        RuntimeError.any_instance.should_receive(:log_me)
        @broadcaster.broadcast :event_type, "Class", 1
      end
    end
  
    it "doesn't broadcast events in the test environment" do
      b = described_class.new
      b.broadcast :event_type, "Class", 1

      expect(b.broadcasted_events.first.event_type).to eq :event_type
    end
  end

end