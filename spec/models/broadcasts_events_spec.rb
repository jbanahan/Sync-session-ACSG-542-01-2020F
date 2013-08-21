require 'spec_helper'

describe BroadcastsEvents do

  before :each do
    BroadcasterTest ||= Class.new do 
      include BroadcastsEvents

      def id 
        1
      end
    end 

    @broadcaster = BroadcasterTest.new
  end

  context :broadcast_event do

    it "should send an event for the included class object" do
      OpenChain::Events::EventBroadcaster.any_instance.should_receive(:broadcast).with :test, "BroadcasterTest", 1, nil
      @broadcaster.broadcast_event(:test).should be_nil
    end 

    it "should accept an event_context" do
      c = {:context_key=>"value"}
      OpenChain::Events::EventBroadcaster.any_instance.should_receive(:broadcast).with :test, "BroadcasterTest", 1, c
      @broadcaster.broadcast_event(:test, c).should be_nil
    end
  end
end