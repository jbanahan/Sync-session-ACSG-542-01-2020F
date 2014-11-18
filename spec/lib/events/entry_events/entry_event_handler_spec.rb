require "spec_helper"

describe OpenChain::Events::EntryEvents::EntryEventHandler do 

  context :listeners do 
    it "should return listeners for save event types" do
      event = double("Event")
      event.stub(:event_type).and_return :save
      listeners = described_class.new.listeners event
      listeners.should have(4).items

      listeners.first.class.name.should == OpenChain::Events::EntryEvents::LandedCostReportAttacherListener.name
      listeners[1].class.name.should == OpenChain::CustomHandler::UnderArmour::UnderArmour315Generator.name
      listeners[2].class.name.should == OpenChain::CustomHandler::Crocs::Crocs210Generator.name
      listeners[3].class.name.should == OpenChain::CustomHandler::FootLocker::FootLocker810Generator.name
    end

    it "should return a blank list for event types it doesn't care about" do
      event = double("Event")
      event.stub(:event_type).and_return "These aren't the droids you're looking for".to_sym
      listeners = described_class.new.listeners event
      listeners.should have(0).items
    end
  end
end