require 'open_chain/registries/password_validation_registry'
require 'open_chain/registries/order_booking_registry'
require 'open_chain/registries/order_acceptance_registry'
require 'open_chain/registries/shipment_registry'
require 'open_chain/anti_virus/anti_virus_registry'

module OpenChain; module CustomHandler; class DefaultInstanceSpecificInit
  def self.init
    if OpenChain::Registries::PasswordValidationRegistry.registered.length == 0
      require "open_chain/registries/default_password_validation_registry"
      OpenChain::Registries::PasswordValidationRegistry.register OpenChain::Registries::DefaultPasswordValidationRegistry
    end

    if OpenChain::Registries::OrderBookingRegistry.registered.length == 0
      require 'open_chain/registries/default_order_booking_registry'
      OpenChain::Registries::OrderBookingRegistry.register OpenChain::Registries::DefaultOrderBookingRegistry
    end

    if OpenChain::Registries::OrderAcceptanceRegistry.registered.length == 0
      require 'open_chain/registries/default_order_acceptance_registry'
      OpenChain::Registries::OrderAcceptanceRegistry.register OpenChain::Registries::DefaultOrderAcceptanceRegistry
    end

    if OpenChain::Registries::ShipmentRegistry.registered.length == 0
      require 'open_chain/registries/default_shipment_registry'
      OpenChain::Registries::ShipmentRegistry.register OpenChain::Registries::DefaultShipmentRegistry
    end

    if OpenChain::AntiVirus::AntiVirusRegistry.registered.length == 0
      # We should only use the actual ClamAV based anti-virus in production
      if MasterSetup.test_env? || MasterSetup.development_env?
        require 'open_chain/anti_virus/testing_anti_virus'
        OpenChain::AntiVirus::AntiVirusRegistry.register OpenChain::AntiVirus::TestingAntiVirus
      else
        require 'open_chain/anti_virus/clamby_anti_virus'
        OpenChain::AntiVirus::AntiVirusRegistry.register OpenChain::AntiVirus::ClambyAntiVirus
      end
      
    end

    if MasterSetup.get.custom_feature?("Document Stitching")
      require 'open_chain/entity_compare/comparator_registry'
      require 'open_chain/custom_handler/vandegrift/entry_attachment_stitch_request_comparator'
      OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::EntryAttachmentStitchRequestComparator
    end
  end
end; end; end
