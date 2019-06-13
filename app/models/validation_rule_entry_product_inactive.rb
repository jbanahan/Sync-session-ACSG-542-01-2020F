# -*- SkipSchemaAnnotations
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

# Checks that products associated with an entry are not inactive
class ValidationRuleEntryProductInactive < BusinessValidationRule
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number]
  end

  def run_validation entry
    ActiveRecord::Associations::Preloader.new(entry, {commercial_invoices: :commercial_invoice_lines}).run
    line_data = entry.commercial_invoices
                     .flat_map(&:commercial_invoice_lines)
                     .map{ |cil| {inv_num: cil.commercial_invoice.invoice_number,
                                  line_num: cil.line_number,
                                  part_num: cil.part_number} }

    # product ids matching line_data part numbers
    prod_part_hsh = Product.create_prod_part_hsh(Product.product_importer(entry, rule_attributes['importer_system_code']).id,
      line_data.map{ |l| l[:part_num] }, cdefs)

    # filter product ids for inactive products
    prods = Product.where(id: prod_part_hsh.keys, inactive: true).map(&:id)

    # part numbers matching filtered product ids
    parts = prod_part_hsh.select{ |k,v| prods.include? k }.values

    # filter line_data matching above part numbers
    line_data_str = line_data.select{ |l| parts.include? l[:part_num]  }
                                .sort_by{ |l| [l[:inv_num], l[:line_num]] }
                                .map{ |l| "Invoice #{l[:inv_num]} / Line #{l[:line_num]} / Part #{l[:part_num]}" }
                                .join("\n")

    if line_data_str.present?
      "Part(s) were found with the inactive (discontinued) flag set:\n#{line_data_str}"
    end
  end
end
