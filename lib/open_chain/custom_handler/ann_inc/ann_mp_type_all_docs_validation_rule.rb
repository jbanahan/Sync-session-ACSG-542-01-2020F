require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
module OpenChain; module CustomHandler; module AnnInc; class AnnMpTypeAllDocsValidationRule < BusinessValidationRule
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
  def run_validation order
    @cdefs = self.class.prep_custom_definitions([:mp_type, :ord_docs_required])
    failures = []
    vend = order.vendor
    failure_message = validate_order(order, vend) if vend.present?
    failures << failure_message if failure_message.present?
    return failures.empty? ? nil : failures.join("\n")
  end

  def validate_order(order, vendor)
    if vendor.get_custom_value(@cdefs[:mp_type]).value == 'All Docs' && order.get_custom_value(@cdefs[:ord_docs_required]).value.blank?
      return "Order does not have Documents Required Set, but Vendor requires All Docs"
    end
  end
end; end; end; end