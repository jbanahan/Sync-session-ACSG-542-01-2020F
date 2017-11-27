class ValidationRuleEntryInvoiceLineMatchesPo < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation invoice_line
    order = find_order get_importer_id(invoice_line), invoice_line.po_number
    return order.nil? ? "No Order found for PO # #{invoice_line.po_number}." : nil
  end

  private
    def find_order importer_id, customer_order_number
      # Involving caching because multiple invoice lines may be hooked to same PO.
      @cache ||= Hash.new do |order_hash, key|
        order_hash[key] = Order.where(importer_id: importer_id, customer_order_number: key).first
      end

      @cache[customer_order_number]
    end

    def get_importer_id invoice_line
      @importer_id ||= rule_attributes["importer_id"].present? ? rule_attributes["importer_id"].to_i : invoice_line.entry.importer_id

      @importer_id
    end

end