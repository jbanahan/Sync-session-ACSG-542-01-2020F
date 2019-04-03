require 'open_chain/custom_handler/pvh/pvh_entry_shipment_matching_support'

# This rule should only be applied to PVH entries and should be skipped until a broker invoice is added.
module OpenChain; module CustomHandler; module Pvh; class PvhValidationRuleEntryInvoiceLineMatchesShipmentLine < BusinessValidationRule
  include OpenChain::CustomHandler::Pvh::PvhEntryShipmentMatchingSupport

  def self.enabled?
    MasterSetup.get.custom_feature? "PVH Feeds"
  end

  def run_validation entry
    shipments = find_shipments(entry.transport_mode_code, Entry.split_newline_values(entry.master_bills_of_lading), Entry.split_newline_values(entry.house_bills_of_lading))
    preload_entry(entry)
    errors = []
    entry.commercial_invoices.each do |i|
      i.commercial_invoice_lines.each do |l|
        if !invoice_line_matches?(shipments, entry, l)
          errors << "PO # #{l.po_number} / Part # #{l.part_number} - Failed to find matching PVH Shipment Line."
        end
      end
    end

    errors.uniq.to_a
  end

  def invoice_line_matches? shipments, entry, line
    find_shipment_line(shipments, line.container&.container_number, line.po_number, line.part_number, line.quantity).present?
  end

  def preload_entry entry
    ActiveRecord::Associations::Preloader.new(entry, {commercial_invoices: {commercial_invoice_lines: :container}}).run
  end

end; end; end; end