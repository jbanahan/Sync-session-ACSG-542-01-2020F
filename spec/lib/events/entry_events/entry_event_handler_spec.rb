describe OpenChain::Events::EntryEvents::EntryEventHandler do

  context "listeners" do
    it "should return listeners for save event types" do
      event = double("Event")
      allow(event).to receive(:event_type).and_return :save
      listeners = described_class.new.listeners event

      expect(listeners.first.class.name).to eq(OpenChain::Events::EntryEvents::LandedCostReportAttacherListener.name)
      expect(listeners[1].class.name).to eq(OpenChain::CustomHandler::UnderArmour::UnderArmour315Generator.name)
      expect(listeners[2].class.name).to eq(OpenChain::CustomHandler::Crocs::Crocs210Generator.name)
      expect(listeners[3].class.name).to eq(OpenChain::CustomHandler::Generator315::Entry315Dispatcher.name)
    end

    it "should return a blank list for event types it doesn't care about" do
      event = double("Event")
      allow(event).to receive(:event_type).and_return "These aren't the droids you're looking for".to_sym
      listeners = described_class.new.listeners event
      expect(listeners.size).to eq(0)
    end
  end
end
