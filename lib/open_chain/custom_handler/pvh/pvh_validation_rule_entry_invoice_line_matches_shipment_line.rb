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
        next if goh_tariff?(l)

        if !invoice_line_matches?(shipments, entry, l)
          errors << "PO # #{l.po_number} / Part # #{l.part_number} - Failed to find matching PVH Shipment Line."
        end
      end
    end

    errors.uniq.to_a
  end

  def invoice_line_matches? shipments, entry, line
    # We only need to worry about matching on the invoice number for Ocean LCL entries, as that's the only billing path where that can make
    # a difference to how the data is pulled from the ASN (due to split container billing)
    #
    # This might be something we should turn on at all times, but I'm hesitant given that I know there are issues with the invoice number
    # on the ASN not being 100% accurate - thus we may raise validation errors and extra work for cases where an invoice number exact match isn't
    # that important
    find_shipment_line(shipments, line.container&.container_number, line.po_number, line.part_number, line.quantity, invoice_number: line.commercial_invoice.invoice_number).present?
  end

  def preload_entry entry
    ActiveRecord::Associations::Preloader.new.preload(entry, {commercial_invoices: {commercial_invoice_lines: [:container, :commercial_invoice_tariffs]}})
  end

  def goh_tariff? invoice_line
    invoice_line.commercial_invoice_tariffs.any? { |t| possible_goh_tariff?(t.hts_code) }
  end

end; end; end; end
