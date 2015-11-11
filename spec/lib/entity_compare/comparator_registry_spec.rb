require 'spec_helper'

describe OpenChain::EntityCompare::ComparatorRegistry do
  before :each do
    @c = Class.new do
      def self.compare type, id, old_bucket, old_doc_path, old_version, new_bucket, new_doc_path, new_version
      end
    end
  end
  describe :register do
    it "should silently allow duplicate registration without creating duplicates" do
      described_class.register(@c)
      described_class.register(@c)
      expect(described_class.registered.collect { |x| x }).to eq [@c]
    end
    it "should only allow class objects" do
      d = double('FaileEvenThoughInterfaceIsGood')
      d.stub(:compare)
      expect{described_class.register(d)}.to raise_error
    end
    it "should only allow objects that respond_to?(:compare)" do
      expect{described_class.register(Object)}.to raise_error
    end
  end
  describe :registered do
    it "should not be changed by modifying retured Enumerable" do
      described_class.register(@c)
      enum = described_class.registered
      expect(enum.to_a).to eq [@c]
      enum.clear
      expect(enum.to_a).to eq []

      expect(described_class.registered.to_a).to eq [@c]
    end
  end
  describe :remove do
    it "should allow removing of non-registered items" do
      described_class.register(@c)
      described_class.remove(Object)
      expect(described_class.registered.to_a).to eq [@c]
    end
    it "should remove items" do
      described_class.register(@c)
      described_class.remove(@c)
      expect(described_class.registered.to_a).to eq []
    end
  end
  describe :clear do
    it "should remove items" do
      described_class.register(@c)
      described_class.clear
      expect(described_class.registered.to_a).to eq []
    end
  end
end