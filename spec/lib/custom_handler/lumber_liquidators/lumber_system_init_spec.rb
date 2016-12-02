require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit do
  describe '#init' do
    before :each do
      allow(OpenChain::CustomHandler::CustomViewSelector).to receive(:register_handler)
      allow(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register)
    end
    it 'should not do anything if system_code != ll' do
      allow_any_instance_of(MasterSetup).to receive(:system_code).and_return('x')
      expect(OpenChain::CustomHandler::CustomViewSelector).not_to receive(:register_handler)
      expect(OpenChain::EntityCompare::ComparatorRegistry).not_to receive(:register)
      OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
    end
    context 'with system code' do
      before(:each) do
        allow_any_instance_of(MasterSetup).to receive(:system_code).and_return('ll')
      end
      it 'should call custom view selector' do
        expect(OpenChain::CustomHandler::CustomViewSelector).
          to receive(:register_handler).
          with(OpenChain::CustomHandler::LumberLiquidators::LumberViewSelector)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end
      it 'should register change comparators' do
        cr = OpenChain::EntityCompare::ComparatorRegistry
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator)
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorAssignmentChangeComparator)
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberProductChangeComparator)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end
      it 'should register order acceptance' do
        oar = OpenChain::OrderAcceptanceRegistry
        expect(oar).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberOrderAcceptance)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end
      it 'should register order booking' do
        expect(OpenChain::OrderBookingRegistry).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberOrderBooking)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end

    end
  end
end
