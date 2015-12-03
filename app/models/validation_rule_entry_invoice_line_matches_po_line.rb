require 'open_chain/custom_handler/vfitrack_custom_definition_support'

class ValidationRuleEntryInvoiceLineMatchesPoLine < BusinessValidationRule
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include ValidatesCommercialInvoiceLine

  def custom_definitions
    @cust_def ||= self.class.prep_custom_definitions [:prod_part_number]
  end

  def run_child_validation invoice_line
    po_number = extract_po_number invoice_line
    part_number = extract_part_number invoice_line

    lines = OrderLine.joins(:order, :product).joins("INNER JOIN custom_values ON custom_values.custom_definition_id = #{custom_definitions[:prod_part_number].id} AND custom_values.customizable_id = products.id AND custom_values.customizable_type = 'Product'")
            .where(orders: {importer_id: invoice_line.entry.importer_id, customer_order_number: po_number})
            .where("custom_values.string_value = ?", part_number)

    if lines.empty?
      # Check if perhaps the PO can be found, that way we can tell user that the PO is there but not the line
      # to give them a better understanding of what's actually wrong with the data.
      order = Order.where(importer_id: invoice_line.entry.importer_id, customer_order_number: po_number).first
      return order.nil? ? "No Order found for PO # #{po_number}." : "No Order Line found for PO # #{po_number} and Part # #{part_number}."
    else
      msgs = validate_invoice_and_po_fields(invoice_line, po_number, part_number, lines)
      return msgs.blank? ? nil : msgs.uniq.join(" \n")
    end

    nil
  end

  def extract_po_number invoice_line
    invoice_line.po_number
  end

  def extract_part_number invoice_line
    invoice_line.part_number
  end

  def validate_invoice_and_po_fields invoice_line, po_number, part_number, order_lines
    # This method is here to provide an extension point for any other validation rules matching
    # against specific invoice line / order line data fields.
    check_match_fields invoice_line, po_number, part_number, order_lines
  end

  private
  def check_match_fields invoice_line, po_number, part_number, order_lines
    msgs = []
    @match_fields ||= get_match_fields
    @match_fields.each do |mf|
      inv_line_model_field = ModelField.find_by_uid(mf['invoice_line_field'])
      inv_line_value = inv_line_model_field.process_export(invoice_line,nil,true)
      ord_line_model_field = ModelField.find_by_uid(mf['order_line_field'])
      sc = SearchCriterion.new(model_field_uid:ord_line_model_field.uid,operator:mf['operator'],value:inv_line_value)
      if !field_matches(sc,order_lines)
        msgs << "No matching order for PO # #{po_number} and Part # #{part_number} where #{ord_line_model_field.label(false)} #{CriterionOperator.find_by_key(mf['operator']).label} #{inv_line_model_field.label(false)} (#{sc.value})"
      end
    end
    msgs
  end
  def field_matches sc, order_lines
    order_lines.each do |ol|
      return true if sc.test? ol
    end
    false
  end
  def get_match_fields
    ra = self.rule_attributes
    return [] if ra.blank?
    return [] if ra['match_fields'].blank?
    ra['match_fields']
  end
end

# need require statements at end because they depend on the class existing
require_dependency 'open_chain/custom_handler/polo/polo_validation_rule_entry_invoice_line_matches_po_line'