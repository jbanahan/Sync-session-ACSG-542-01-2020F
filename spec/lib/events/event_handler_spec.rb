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
    allow(@object).to receive(:class).and_return "Testing"
  end

  context :handle do

    it "should process a single event" do
      l1 = double("Listener1")
      expect(l1).to receive(:accepts?).with(@e, @object).and_return true
      expect(l1).to receive(:receive).with(@e, @object).and_return nil

      expect(@h).to receive(:listeners).and_return [l1]
      expect(@h).to receive(:find).with(@e).and_return @object

      expect(@h.handle(@e)).to be_nil
    end

    it "should filter listeners that don't accept the event or object" do
      l1 = double("Listener1")
      expect(l1).to receive(:accepts?).with(@e, @object).and_return true
      l2 = double("Listener1")
      expect(l2).to receive(:accepts?).with(@e, @object).and_return false

      expect(l1).to receive(:receive).with(@e, @object).and_return nil

      expect(@h).to receive(:listeners).and_return [l1, l2]
      expect(@h).to receive(:find).with(@e).and_return @object

      expect(@h.handle(@e)).to be_nil
    end

    it "should pass updated event objects to the next listener" do
      l1 = double("Listener1")
      expect(l1).to receive(:accepts?).with(@e, @object).and_return true
      l2 = double("Listener1")
      expect(l2).to receive(:accepts?).with(@e, @object).and_return true
      l3 = double("Listener1")
      expect(l3).to receive(:accepts?).with(@e, @object).and_return true


      @updated = double("Updated Object")
      allow(@updated).to receive(:class).and_return "Testing"

      expect(l1).to receive(:receive).with(@e, @object).and_return @updated
      # Make sure we handle cases where a listener accidently returns object that are not
      # the same type that the original event object was
      expect(l2).to receive(:receive).with(@e, @updated).and_return "Don't use"
      expect(l3).to receive(:receive).with(@e, @updated).and_return nil

      expect(@h).to receive(:listeners).and_return [l1, l2, l3]
      expect(@h).to receive(:find).with(@e).and_return @object

      expect(@h.handle(@e)).to be_nil
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
      expect(found).to eq("Test")
    end

    it "should find an ActiveRecord model" do
      # Just make sure this works fine with a "real" model object
      entry = Factory(:entry)
      @e.object_class = entry.class.name
      @e.object_id = entry.id

      found = @h.find @e
      expect(found.id).to eq(entry.id)
    end
  end
end