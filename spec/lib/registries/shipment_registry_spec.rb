describe OpenChain::Registries::ShipmentRegistry do
  describe 'register' do
    it "should register if implements can_cancel? and can_uncancel?" do
      c = Class.new do
        def self.can_cancel?(shipment, user); true; end
        def self.can_uncancel?(shipment, user); true; end
      end

      described_class.register c
      expect(described_class.registered.to_a).to eq [c]
    end

    it "should fail if doesn't implement can_cancel?" do
      c = Class.new do
        def self.can_uncancel?(shipment, user); true; end
      end

      expect {described_class.register c}.to raise_error(/can_cancel/)
      expect(described_class.registered.to_a).to be_empty
    end

    it "should fail if doesn't implement can_request_uncancel?" do
      c = Class.new do
        def self.can_cancel?(shipment, user); true; end
      end

      expect {described_class.register c}.to raise_error(/can_uncancel/)
      expect(described_class.registered.to_a).to be_empty
    end
  end
end
