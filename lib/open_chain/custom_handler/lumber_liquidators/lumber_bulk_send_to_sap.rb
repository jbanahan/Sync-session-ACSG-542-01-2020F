require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class BulkSendToSap
  include LumberCustomDefinitionSupport

  def self.bulk_type
    'Bulk Send To SAP'
  end

  def self.act user, id, opts, bulk_process_log, sequence
    ord = Order.find id
    if ord && ord.can_view?(user)
      OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator.send_order ord, force_send: true

      # Populate a custom date field with the current date indicating that the order was manually sent to SAP.
      @cdefs = prep_custom_definitions [:ord_manual_send_to_sap_date]
      ord.update_custom_value! @cdefs[:ord_manual_send_to_sap_date], Time.zone.now

      ord.create_snapshot user, nil, "Manual SAP Send"
    end
  end

end; end; end; end