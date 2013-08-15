require "spec_helper"

describe OpenChain::Events::EntryEvents::EntryEventHandler do 

  context :listeners do 
    it "should return listeners for save event types" do
      event = double("Event")
      event.stub(:event_type).and_return :save
      listeners = described_class.new.listeners event
      listeners.should have(1).item

      listeners.first.class.name.should == OpenChain::Events::EntryEvents::LandedCostReportAttacherListener.name
    end

    it "should return a blank list for event types it doesn't care about" do
      event = double("Event")
      event.stub(:event_type).and_return "These aren't the droids you're looking for".to_sym
      listeners = described_class.new.listeners event
      listeners.should have(0).items
    end
  end
end