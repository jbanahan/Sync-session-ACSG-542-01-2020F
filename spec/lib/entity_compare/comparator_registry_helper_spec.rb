describe OpenChain::EntityCompare::ComparatorRegistryHelper do
  let (:comparator) {
    Class.new do
      def self.compare; end
      def self.accept?; end
    end
  }

  let (:registry) {
    Class.new do 
      extend OpenChain::EntityCompare::ComparatorRegistryHelper
    end
  }

  describe "register" do
    it "should silently allow duplicate registration without creating duplicates" do
      registry.register(comparator)
      registry.register(comparator)
      expect(registry.registered.collect { |x| x }).to eq [comparator]
    end
    it "should only allow class objects" do
      d = double('FaileEvenThoughInterfaceIsGood')
      allow(d).to receive(:compare)
      expect{registry.register(d)}.to raise_error(/be a class/)
    end
    it "should only allow objects that respond_to?(:compare)" do
      expect{registry.register(Object)}.to raise_error "All comparators must respond to #compare"
    end

    it "forces comparators to implement accept? method" do
      c = Class.new { def self.compare; end }
      expect{registry.register(c)}.to raise_error "All comparators must respond to #accept?"
    end
  end
  describe "registered" do
    it "should not be changed by modifying retured Enumerable" do
      registry.register(comparator)
      enum = registry.registered
      expect(enum.to_a).to eq [comparator]
      enum.clear
      expect(enum.to_a).to eq []

      expect(registry.registered.to_a).to eq [comparator]
    end
  end
  describe "remove" do
    it "should allow removing of non-registered items" do
      registry.register(comparator)
      registry.remove(Object)
      expect(registry.registered.to_a).to eq [comparator]
    end
    it "should remove items" do
      registry.register(comparator)
      registry.remove(comparator)
      expect(registry.registered.to_a).to eq []
    end
  end
  describe "clear" do
    it "should remove items" do
      registry.register(comparator)
      registry.clear
      expect(registry.registered.to_a).to eq []
    end
  end
end
