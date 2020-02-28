module OpenChain; module CustomHandler; module Pepsi; class PepsiSystemInit
  def self.init
    return unless MasterSetup.get.custom_feature?("Pepsi")

    require 'open_chain/entity_compare/comparator_registry'
    require 'open_chain/custom_handler/pepsi/pepsi_quaker_product_approval_reset_comparator'

    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Pepsi::PepsiQuakerProductApprovalResetComparator
  end
end; end; end; end
