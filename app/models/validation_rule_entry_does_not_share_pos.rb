# -*- SkipSchemaAnnotations
class ValidationRuleEntryDoesNotSharePos < BusinessValidationRule

  def run_validation entry
    msgs = []

    po_numbers = get_purchase_order_numbers entry
    po_numbers.each do |po_number|
      # Look for lines on other entries (from the same importer) that share this PO number.  Any matches need to be
      # written to the errors array.  Per this rule, a PO cannot span entries.
      lines = CommercialInvoiceLine.joins(:entry).where(entries: {importer_id: entry.importer_id}).where(po_number: po_number).where("entries.id <> ?", entry.id)
      lines.each do |invoice_line|
        msgs << "Purchase Order #{po_number} already exists on Entry #{invoice_line.entry.entry_number} for Invoice #{invoice_line.commercial_invoice.invoice_number}, and line number #{invoice_line.line_number}."
      end
    end

    return msgs.blank? ? nil : msgs.uniq.join(" \n")
  end

  private
    # Extracts unique set of PO numbers from the entry's invoice lines.
    def get_purchase_order_numbers entry
      po_numbers = Set.new
      entry.commercial_invoices.each do |invoice|
        invoice.commercial_invoice_lines.each do |invoice_line|
          po_numbers << invoice_line.po_number if invoice_line.po_number.present?
        end
      end
      po_numbers.to_a
    end

end
