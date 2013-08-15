require 'spec_helper'

describe OpenChain::Events::EventHandler do

  before :each do
    @h = Class.new do 
      include OpenChain::Events::EventHandler
    end.new

    @e = OpenChain::Events::OpenChainEvent.new
    @e.event_type = :test
    @e.object_class = "Testing"
    @e.object_id = -1

    @object = double("Module Object")
    @object.stub(:class).and_return "Testing"
  end

  context :handle do

    it "should process a single event" do
      l1 = double("Listener1")
      l1.should_receive(:accepts?).with(@e, @object).and_return true
      l1.should_receive(:receive).with(@e, @object).and_return nil

      @h.should_receive(:listeners).and_return [l1]
      @h.should_receive(:find).with(@e).and_return @object

      @h.handle(@e).should be_nil
    end

    it "should filter listeners that don't accept the event or object" do
      l1 = double("Listener1")
      l1.should_receive(:accepts?).with(@e, @object).and_return true
      l2 = double("Listener1")
      l2.should_receive(:accepts?).with(@e, @object).and_return false

      l1.should_receive(:receive).with(@e, @object).and_return nil

      @h.should_receive(:listeners).and_return [l1, l2]
      @h.should_receive(:find).with(@e).and_return @object

      @h.handle(@e).should be_nil
    end

    it "should pass updated event objects to the next listener" do
      l1 = double("Listener1")
      l1.should_receive(:accepts?).with(@e, @object).and_return true
      l2 = double("Listener1")
      l2.should_receive(:accepts?).with(@e, @object).and_return true
      l3 = double("Listener1")
      l3.should_receive(:accepts?).with(@e, @object).and_return true


      @updated = double("Updated Object")
      @updated.stub(:class).and_return "Testing"

      l1.should_receive(:receive).with(@e, @object).and_return @updated
      # Make sure we handle cases where a listener accidently returns object that are not
      # the same type that the original event object was
      l2.should_receive(:receive).with(@e, @updated).and_return "Don't use"
      l3.should_receive(:receive).with(@e, @updated).and_return nil

      @h.should_receive(:listeners).and_return [l1, l2, l3]
      @h.should_receive(:find).with(@e).and_return @object

      @h.handle(@e).should be_nil
    end

    it "should rescue errors raised from listeners" do
      l1 = double("Listener1")
      l1.should_receive(:accepts?).with(@e, @object).and_return true
      l2 = double("Listener1")
      l2.should_receive(:accepts?).with(@e, @object).and_return true

      l1.should_receive(:receive).with(@e, @object).and_raise "Error"
      l2.should_receive(:receive).with(@e, @object).and_return nil

      @h.should_receive(:listeners).and_return [l1, l2]
      @h.should_receive(:find).with(@e).and_return @object

      RuntimeError.any_instance.should_receive(:log_me)
      @h.handle(@e).should be_nil
    end
  end

  context :find do
    it "should find an event object using the find_by_id method" do
      # This makes sure we're handling potential namespaced classes as well as just
      # using the find_by_id method to do the object lookup
      module EventTest
        class TestObject
          def self.find_by_id id
            "Test"
          end
        end
      end

      @e.object_class = EventTest::TestObject.name
      found = @h.find @e
      found.should == "Test"
    end

    it "should find an ActiveRecord model" do
      # Just make sure this works fine with a "real" model object
      entry = Factory(:entry)
      @e.object_class = entry.class.name
      @e.object_id = entry.id

      found = @h.find @e
      found.id.should == entry.id
    end
  end
end