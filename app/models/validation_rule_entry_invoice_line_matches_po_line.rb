class ValidationRuleEntryInvoiceLineMatchesPoLine < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation invoice_line
    @part_no_cd ||= CustomDefinition.where(label: "Part Number", module_type: "Product").first
    raise "Unable to find Part Number custom field for Product module." unless @part_no_cd

    line = OrderLine.joins(:order, :product).joins("INNER JOIN custom_values ON custom_values.custom_definition_id = #{@part_no_cd.id} AND custom_values.customizable_id = products.id AND custom_values.customizable_type = 'Product'")
            .where(orders: {importer_id: invoice_line.entry.importer_id, customer_order_number: invoice_line.po_number})
            .where("custom_values.string_value = ?", invoice_line.part_number).first

    if line.nil?
      # Check if perhaps the PO can be found, that way we can tell user that the PO is there but not the line
      # to give them a better understanding of what's actually wrong with the data.
      order = Order.where(importer_id: invoice_line.entry.importer_id, customer_order_number: invoice_line.po_number).first
      return order.nil? ? "No Order found for PO # #{invoice_line.po_number}." : "No Order Line found for PO # #{invoice_line.po_number} and Part # #{invoice_line.part_number}."
    end

    nil
  end
end