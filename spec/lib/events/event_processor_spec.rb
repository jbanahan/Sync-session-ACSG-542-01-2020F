require "spec_helper"

describe OpenChain::Events::EventProcessor do

  context :process_event do

    it "should create a handler and pass the event to it" do
      event = double("Event")
      # Entry is the only real handler currently set up at this point.
      allow(event).to receive(:object_class).and_return "Entry"
      expect_any_instance_of(OpenChain::Events::EntryEvents::EntryEventHandler).to receive(:handle).with(event)
      described_class.new.process_event event
    end

    it "should raise an error if no handler is found for an event" do
      event = double("Event")
      allow(event).to receive(:object_class).and_return "No Handler For Me!"
      expect {described_class.new.process_event event}.to raise_error "No module event hander is configured for #{event.object_class} events."
    end
  end

  context :module_event_handler do

    before :each do
      @proc = described_class.new
      # work around protected method
      def @proc.handler event 
        module_event_handler event
      end
    end

    it "should return entry event handler for entry events" do
      event = double("Event")
      allow(event).to receive(:object_class).and_return "Entry"
      handler = @proc.handler event
      expect(handler.class.name).to eq(OpenChain::Events::EntryEvents::EntryEventHandler.name)
    end

    it "returns IsfEvent handler for SecurityFiling events" do
      event = double("Event")
      allow(event).to receive(:object_class).and_return SecurityFiling.name
      handler = @proc.handler event
      expect(handler.class.name).to eq OpenChain::Events::IsfEvents::IsfEventHandler.name
    end

    it "should return nil for event classes it doesn't know about" do
      event = double("Event")
      allow(event).to receive(:object_class).and_return "You don't know me"
      expect(@proc.handler(event)).to be_nil
    end
  end
end