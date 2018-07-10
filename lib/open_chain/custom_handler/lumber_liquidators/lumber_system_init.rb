module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSystemInit
  def self.init
    return unless MasterSetup.get.custom_feature?("Lumber Liquidators")

    # Adding requires in here so they're not required on non-LL systems
    require 'open_chain/entity_compare/comparator_registry'
    require 'open_chain/registries/order_acceptance_registry'
    require 'open_chain/registries/order_booking_registry'
    require 'open_chain/registries/password_validation_registry'
    require 'open_chain/registries/customized_api_response_registry'
    require 'open_chain/registries/shipment_registry'
    require 'open_chain/custom_handler/custom_view_selector'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_view_selector'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_entry_packet_shipment_change_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_order_acceptance'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_order_booking'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_order_change_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_product_change_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_product_vendor_assignment_change_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_factory_pack_shipment_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_booking_request_shipment_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_isf_shipment_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_vgm_shipment_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_api_response'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_password_validation_registry'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_shipment_registry'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_order_booked_data_recorder_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_order_shipped_data_recorder_comparator'
    require 'open_chain/custom_handler/lumber_liquidators/lumber_shipment_order_data_recorder_comparator'

    OpenChain::CustomHandler::CustomViewSelector.register_handler OpenChain::CustomHandler::LumberLiquidators::LumberViewSelector
    OpenChain::Registries::OrderAcceptanceRegistry.register OpenChain::CustomHandler::LumberLiquidators::LumberOrderAcceptance
    OpenChain::Registries::OrderBookingRegistry.register OpenChain::CustomHandler::LumberLiquidators::LumberOrderBooking
    OpenChain::Registries::PasswordValidationRegistry.register OpenChain::CustomHandler::LumberLiquidators::LumberPasswordValidationRegistry
    OpenChain::Registries::CustomizedApiResponseRegistry.register OpenChain::CustomHandler::LumberLiquidators::LumberCustomApiResponse
    OpenChain::Registries::ShipmentRegistry.register OpenChain::CustomHandler::LumberLiquidators::LumberShipmentRegistry

    register_change_comparators
  end

  def self.register_change_comparators
    [
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorAssignmentChangeComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberProductChangeComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberEntryPacketShipmentChangeComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberVgmShipmentComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberFactoryPackShipmentComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestShipmentComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderBookedDataRecorderComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderShippedDataRecorderComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberShipmentOrderDataRecorderComparator
    ].each {
      |c| OpenChain::EntityCompare::ComparatorRegistry.register c
    }
  end
  private_class_method :register_change_comparators
end; end; end; end
