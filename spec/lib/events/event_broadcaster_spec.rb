require "spec_helper"

describe OpenChain::Events::EventBroadcaster do

  context :broadcast do
    it "should create an event processor and sent an event to it" do
      OpenChain::Events::EventProcessor.any_instance.should_receive(:process_event) do |e|
        e.event_type.should == :event_type
        e.object_class.should == "Class"
        e.object_id.should == 1
        e.event_context.should == "Context"
      end

      described_class.new.broadcast :event_type, "Class", 1, "Context"
    end

    it "should default context to nil" do
      OpenChain::Events::EventProcessor.any_instance.should_receive(:process_event) do |e|
        e.event_type.should == :event_type
        e.object_class.should == "Class"
        e.object_id.should == 1
        e.event_context.should be_nil
      end

      described_class.new.broadcast :event_type, "Class", 1
    end

  end

end