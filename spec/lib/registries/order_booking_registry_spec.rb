describe OpenChain::Registries::OrderBookingRegistry do
  before :each do
    described_class.clear
  end
  describe '#register' do
    it "should register if implments can_book?, can_request_booking? and can_revise_booking?" do
      c = Class.new do
        def self.can_book?(ord, user); true; end
        def self.can_request_booking?(ord, user); true; end
        def self.can_revise_booking?(ord, user); true; end
        def self.can_edit_booking?(ord, user); true; end
      end

      described_class.register c
      expect(described_class.registered.to_a).to eq [c]
    end

    it "should fail if doesn't implement can_book?" do
      c = Class.new do
        def self.can_request_booking?(ord, user); true; end
        def self.can_revise_booking?(ord, user); true; end
        def self.can_edit_booking?(ord, user); true; end
      end

      expect{described_class.register c}.to raise_error(/can_book/)
      expect(described_class.registered.to_a).to be_empty
    end

    it "should fail if doesn't implement can_request_booking?" do
      c = Class.new do
        def self.can_book?(ord, user); true; end
        def self.can_revise_booking?(ord, user); true; end
        def self.can_edit_booking?(ord, user); true; end
      end

      expect{described_class.register c}.to raise_error(/can_request_book/)
      expect(described_class.registered.to_a).to be_empty
    end

    it "should fail if doesn't implement can_revise_booking?" do
      c = Class.new do
        def self.can_book?(ord, user); true; end
        def self.can_request_booking?(ord, user); true; end
        def self.can_edit_booking?(ord, user); true; end
      end

      expect{described_class.register c}.to raise_error(/can_revise_book/)
      expect(described_class.registered.to_a).to be_empty
    end

    it "should fail if doesn't implement can_edit_booking?" do
      c = Class.new do
        def self.can_book?(ord, user); true; end
        def self.can_request_booking?(ord, user); true; end
        def self.can_revise_booking?(ord, user); true; end
      end

      expect{described_class.register c}.to raise_error(/can_edit_book/)
      expect(described_class.registered.to_a).to be_empty
    end
  end
end
