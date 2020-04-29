describe OpenChain::ServiceLocator do

  subject {
    Class.new do
      extend OpenChain::ServiceLocator
    end
  }
  let (:service) {
    Class.new
  }
  let (:parent_service) {
    Class.new do
      def self.child_services
        @services ||= [Object.new]
      end
    end
  }

  describe "register" do
    it "should silently allow duplicate registration without creating duplicates" do
      subject.register(service)
      subject.register(service)
      expect(subject.registered.to_a).to eq [service]
    end
    it "should pass if has validator that passes" do
      def subject.check_validity obj; end
      subject.register(service)
      expect(subject.registered.to_a).to eq [service]
    end
    it "should raise error if has validator that raises error" do
      def subject.check_validity obj; raise "something"; end
      expect {subject.register(service)}.to raise_error "something"
      expect(subject.registered).to be_empty
    end

    it "looks for child_services on service object" do
      expect(subject).to receive(:add_to_internal_registry).with parent_service.child_services

      subject.register parent_service
    end

    it "calls callback method" do
      def service.registered; ;end
      expect(service).to receive(:registered)

      subject.register service
    end

    it "calls callback method for all child services" do
      parent_service.child_services.each do |s|
        def s.registered; ; end
        expect(s).to receive(:registered)
      end

      subject.register parent_service
    end
  end

  describe "registered" do
    it "should not be changed by modifying retured Enumerable" do
      subject.register(service)
      enum = subject.registered
      expect(enum.to_a).to eq [service]
      enum.clear
      expect(enum.to_a).to eq []

      expect(subject.registered.to_a).to eq [service]
    end
  end

  describe "remove" do
    it "should allow removing of non-registered items" do
      subject.register(service)
      subject.remove(Object)
      expect(subject.registered.to_a).to eq [service]
    end
    it "should remove items" do
      subject.register(service)
      subject.remove(service)
      expect(subject.registered.to_a).to eq []
    end
  end

  describe "clear" do
    it "should remove items" do
      subject.register(service)
      subject.clear
      expect(subject.registered.to_a).to eq []
    end
  end
end
