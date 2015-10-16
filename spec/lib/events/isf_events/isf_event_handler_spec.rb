require "spec_helper"

describe OpenChain::Events::IsfEvents::IsfEventHandler do 

  context :listeners do 
    it "should return listeners for save event types" do
      event = double("Event")
      event.stub(:event_type).and_return :save
      listeners = subject.listeners event
      expect(listeners.first.class.name).to eq OpenChain::CustomHandler::Isf315Generator.name
    end

    it "should return a blank list for event types it doesn't care about" do
      event = double("Event")
      event.stub(:event_type).and_return "These aren't the droids you're looking for".to_sym
      listeners = described_class.new.listeners event
      listeners.should have(0).items
    end
  end
end