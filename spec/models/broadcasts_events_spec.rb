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

  context "broadcast_event" do

    it "should send an event for the included class object" do
      expect_any_instance_of(OpenChain::Events::EventBroadcaster).to receive(:broadcast).with :test, "BroadcasterTest", 1, nil
      expect(@broadcaster.broadcast_event(:test)).to be_nil
    end 

    it "should accept an event_context" do
      c = {:context_key=>"value"}
      expect_any_instance_of(OpenChain::Events::EventBroadcaster).to receive(:broadcast).with :test, "BroadcasterTest", 1, c
      expect(@broadcaster.broadcast_event(:test, c)).to be_nil
    end
  end
end