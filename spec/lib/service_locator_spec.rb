require 'spec_helper'

describe OpenChain::ServiceLocator do
  before :each do
    @k = Class.new do
      extend OpenChain::ServiceLocator
    end
    @c = Class.new
  end
  describe :register do
    it "should silently allow duplicate registration without creating duplicates" do
      @k.register(@c)
      @k.register(@c)
      expect(@k.registered.to_a).to eq [@c]
    end
    it "should pass if has validator that passes" do
      def @k.check_validity obj; end
      @k.register(@c)
      expect(@k.registered.to_a).to eq [@c]
    end
    it "should raise error if has validator that raises error" do
      def @k.check_validity obj; raise "something"; end
      expect{@k.register(@c)}.to raise_error "something"
      expect(@k.registered).to be_empty
    end
  end
  describe :registered do
    it "should not be changed by modifying retured Enumerable" do
      @k.register(@c)
      enum = @k.registered
      expect(enum.to_a).to eq [@c]
      enum.clear
      expect(enum.to_a).to eq []

      expect(@k.registered.to_a).to eq [@c]
    end
  end
  describe :remove do
    it "should allow removing of non-registered items" do
      @k.register(@c)
      @k.remove(Object)
      expect(@k.registered.to_a).to eq [@c]
    end
    it "should remove items" do
      @k.register(@c)
      @k.remove(@c)
      expect(@k.registered.to_a).to eq []
    end
  end
  describe :clear do
    it "should remove items" do
      @k.register(@c)
      @k.clear
      expect(@k.registered.to_a).to eq []
    end
  end
end
