require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit do
  describe '#init' do
    
    before :each do
      allow(OpenChain::CustomHandler::CustomViewSelector).to receive(:register_handler)
      allow(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register)
    end

    it 'should not do anything if "Lumber Liquidators" custom feature is not enabled' do
      master_setup = stub_master_setup
      expect(master_setup).to receive(:custom_feature?).with("Lumber Liquidators").and_return false

      expect(OpenChain::CustomHandler::CustomViewSelector).not_to receive(:register_handler)
      expect(OpenChain::EntityCompare::ComparatorRegistry).not_to receive(:register)
      OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
    end

    context 'with "Lumber Liquidators" custom feature' do
      let! (:ms) {
        m = stub_master_setup
        allow(m).to receive(:custom_feature?).with("Lumber Liquidators").and_return true
        m
      }

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
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberEntryPacketShipmentChangeComparator)
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberVgmShipmentComparator)
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberFactoryPackShipmentComparator)
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentComparator)
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestShipmentComparator)
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberOrderBookedDataRecorderComparator)
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberOrderShippedDataRecorderComparator)
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberShipmentOrderDataRecorderComparator)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end

      it 'should register order acceptance' do
        oar = OpenChain::Registries::OrderAcceptanceRegistry
        expect(oar).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberOrderAcceptance)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end

      it 'should register order booking' do
        expect(OpenChain::Registries::OrderBookingRegistry).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberOrderBooking)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end

      it 'should register password validation' do
        expect(OpenChain::Registries::PasswordValidationRegistry).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberPasswordValidationRegistry)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end

      it "registers custom api response" do
        expect(OpenChain::Registries::CustomizedApiResponseRegistry).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberCustomApiResponse)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end

      it 'should register shipment' do
        expect(OpenChain::Registries::ShipmentRegistry).to receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberShipmentRegistry)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end
    end
  end
end
