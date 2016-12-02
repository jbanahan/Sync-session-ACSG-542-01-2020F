require 'spec_helper'

describe OpenChain::CustomHandler::CustomViewSelector do
  describe '#order_view' do
    before :each do
      @o = double('order')
      @u = double('user')
    end
    after :each do
      described_class.register_handler nil
    end
    it 'should pass through to registered handler' do
      handler = Class.new do
        def self.order_view o, u
          return 'x'
        end
      end

      described_class.register_handler handler

      expect(described_class.order_view(@o,@u)).to eq 'x'
    end
    it 'should return nil if no registered handler' do
      expect(described_class.order_view(@o,@u)).to be_nil
    end
    it "should return nil if regiestered handler doesn't implement method" do
      handler = Class.new
      described_class.register_handler handler
      expect(described_class.order_view(@o,@u)).to be_nil
    end
  end

  describe '#shipment_view' do
    before :each do
      @s = double('shipment')
      @u = double('user')
    end
    after(:each) do
      described_class.register_handler nil
    end
    it 'should pass through to registered handler' do
      handler = Class.new do
        def self.shipment_view s, u
          return 'x'
        end
      end

      described_class.register_handler handler

      expect(described_class.shipment_view(@s,@u)).to eq 'x'
    end
    it 'should return nil if no registered handler' do
      expect(described_class.shipment_view(@s,@u)).to be_nil
    end
    it "should return nil if regiestered handler doesn't implement method" do
      handler = Class.new
      described_class.register_handler handler
      expect(described_class.shipment_view(@s,@u)).to be_nil
    end
  end
end
