require 'spec_helper'

describe OpenChain::OrderAcceptanceRegistry do
  before :each do
    described_class.clear
  end
  describe '#register' do
    it "should register if implements can_be_accepted? and can_accept?" do
      c = Class.new do
        def self.can_be_accepted? ord
        end
        def self.can_accept? ord, user
        end
      end

      described_class.register c
      expect(described_class.registered.to_a).to eq [c]
    end
    it "should fail if doesn't implement can_be_accepted? or can_accept?" do
      c = Class.new do
      end

      expect{described_class.register c}.to raise_error(/accept/)
      expect(described_class.registered.to_a).to be_empty
    end
    it "should pass if only implements can_be_accepted?" do
      c = Class.new do
        def self.can_be_accepted? ord
        end
      end

      described_class.register c
      expect(described_class.registered.to_a).to eq [c]
    end
    it "should pass if only implements can_accept?" do
      c = Class.new do
        def self.can_accept? ord
        end
      end

      described_class.register c
      expect(described_class.registered.to_a).to eq [c]
    end
  end

  context 'specific registry getters' do
    before :each do
      @ca = Class.new do
        def self.can_accept? ord
        end
      end
      @cba = Class.new do
        def self.can_be_accepted? ord
        end
      end
      [@ca,@cba].each {|c| described_class.register c}
    end

    describe '#registered_for_can_accept' do
      it "should only return registered classes that respond to can_accept?" do
        expect(described_class.registered_for_can_accept).to eq [@ca]
      end
    end
    describe '#registered_for_can_be_accepted' do
      it "should only return registered classes that respond to can_be_accepted?" do
        expect(described_class.registered_for_can_be_accepted).to eq [@cba]
      end
    end
  end
end
