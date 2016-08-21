require 'spec_helper'

describe OpenChain::EntityCompare::ComparatorRegistry do
  let (:comparator) {
    Class.new do
      def self.compare; end
      def self.accept?; end
    end
  }
  describe "register" do
    it "should silently allow duplicate registration without creating duplicates" do
      described_class.register(comparator)
      described_class.register(comparator)
      expect(described_class.registered.collect { |x| x }).to eq [comparator]
    end
    it "should only allow class objects" do
      d = double('FaileEvenThoughInterfaceIsGood')
      allow(d).to receive(:compare)
      expect{described_class.register(d)}.to raise_error
    end
    it "should only allow objects that respond_to?(:compare)" do
      expect{described_class.register(Object)}.to raise_error "All comparators must respond to #compare"
    end

    it "forces comparators to implement accept? method" do
      c = Class.new { def self.compare; end }
      expect{described_class.register(c)}.to raise_error "All comparators must respond to #accept?"
    end
  end
  describe "registered" do
    it "should not be changed by modifying retured Enumerable" do
      described_class.register(comparator)
      enum = described_class.registered
      expect(enum.to_a).to eq [comparator]
      enum.clear
      expect(enum.to_a).to eq []

      expect(described_class.registered.to_a).to eq [comparator]
    end
  end
  describe "remove" do
    it "should allow removing of non-registered items" do
      described_class.register(comparator)
      described_class.remove(Object)
      expect(described_class.registered.to_a).to eq [comparator]
    end
    it "should remove items" do
      described_class.register(comparator)
      described_class.remove(comparator)
      expect(described_class.registered.to_a).to eq []
    end
  end
  describe "clear" do
    it "should remove items" do
      described_class.register(comparator)
      described_class.clear
      expect(described_class.registered.to_a).to eq []
    end
  end
end
