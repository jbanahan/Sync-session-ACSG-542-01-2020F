describe OpenChain::Registries::OrderAcceptanceRegistry do

  subject { described_class }
  
  let (:service) {
    Class.new do
      def self.can_be_accepted? ord
      end
      def self.can_accept? ord, user
      end
    end
  }

  let (:order) { Order.new }
  let (:user) { User.new }

  describe '#register' do
    it "should register if implements can_be_accepted? and can_accept?" do
      subject.register service
      expect(subject.registered.to_a).to eq [service]
    end
    it "should fail if doesn't implement can_be_accepted? and can_accept?" do
      c = Class.new do
      end

      expect{subject.register c}.to raise_error(/accept/)
      expect(subject.registered.to_a).to be_empty
    end
  end

  describe "can_accept?" do
    it "evaluates registered services' can_accept? method" do
      subject.register service
      expect(service).to receive(:can_accept?).with(order, user).and_return true
      expect(subject.can_accept? order, user).to eq true
    end
  end

  describe "can_be_accepted?" do
    it "evaluates registered services' can_be_accepted? method" do
      subject.register service
      expect(service).to receive(:can_be_accepted?).with(order).and_return true
      expect(subject.can_be_accepted? order).to eq true
    end
  end
end
