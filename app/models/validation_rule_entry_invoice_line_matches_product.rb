# -*- SkipSchemaAnnotations

# Compare an invoice line field to a product header field.
# Requires `product_model_field_uid` and `line_model_field_uid` attributes.
# Optionally takes `product_importer_system_code` if the product isn't associated with the entry's importer.
# Assumes every line can be linked to a product through its `prod_part_number` custom value.
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

class ValidationRuleEntryInvoiceLineMatchesProduct < BusinessValidationRule
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include ValidatesCommercialInvoiceLine

  def run_child_validation invoice_line
    prod = Product.joins(:custom_values)
                  .find_by(importer_id: product_importer_id(invoice_line),
                           custom_values: {custom_definition_id: part_number_cdef.id, string_value: invoice_line.part_number})

    return %(No part number "#{invoice_line.part_number}" found.) unless prod

    ln_field = line_field(invoice_line)
    prod_field_value = product_field_value(prod)

    if ln_field[:value] != prod_field_value
      %(Expected #{ln_field[:label]} to be "#{prod_field_value}" but found "#{ln_field[:value]}".)
    end
  end

  private

  def product_importer_id invoice_line
    @product_importer_id ||= find_product_importer_id(invoice_line)
  end

  def find_product_importer_id invoice_line
    sys_code = rule_attributes['product_importer_system_code']
    if sys_code.blank?
      # Use entry's importer for the product lookup
      invoice_line.commercial_invoice.entry.importer_id
    else
      Company.find_by(system_code: sys_code).id
    end
  end

  def part_number_cdef
    @part_number_cdef ||= self.class.prep_custom_definitions([:prod_part_number])[:prod_part_number]
  end

  def product_field_value product
    ModelField.by_uid(rule_attributes['product_model_field_uid']).process_export(product, nil)
  end

  def line_field line
    mf = ModelField.by_uid(rule_attributes['line_model_field_uid'])
    {label: mf.label, value: mf.process_export(line, nil)}
  end

end
