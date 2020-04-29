# -*- SkipSchemaAnnotations

require 'open_chain/custom_handler/vfitrack_custom_definition_support'

# Checks that an entry with at least one F&W product has fish_and_wildlife_transmitted_date.
# Does NOT check the reverse, i.e., that the date only exists when there's an F&W product.

class ValidationRuleEntryFishWildlifeTransmittedDateFilled < BusinessValidationRule
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number, :prod_fish_wildlife]
  end

  def run_validation entry
    return nil if entry.fish_and_wildlife_transmitted_date
    ActiveRecord::Associations::Preloader.new.preload(entry, {commercial_invoices: :commercial_invoice_lines})
    line_data = entry.commercial_invoices
                     .flat_map(&:commercial_invoice_lines)
                     .map { |cil| {inv_num: cil.commercial_invoice.invoice_number,
                                   line_num: cil.line_number,
                                   part_num: cil.part_number} }

    # product ids matching line_data part numbers
    prod_part_hsh = Product.create_prod_part_hsh(Product.product_importer(entry, rule_attributes["importer_system_code"]).id,
      line_data.map { |l| l[:part_num] }, cdefs)

    # filter product ids for fish and wildlife
    fw_prods = CustomValue.where(custom_definition_id: cdefs[:prod_fish_wildlife].id,
                                 customizable_id: prod_part_hsh.keys,
                                 boolean_value: true)
                          .map(&:customizable_id)

    # part numbers matching filtered product ids
    fw_parts = prod_part_hsh.select { |k, v| fw_prods.include? k }.values

    # filter line_data matching above part numbers
    fw_line_data_str = line_data.select { |l| fw_parts.include? l[:part_num]  }
                                .sort_by { |l| [l[:inv_num], l[:line_num]] }
                                .map { |l| "invoice #{l[:inv_num]} / line #{l[:line_num]} / part #{l[:part_num]}" }
                                .join("\n")

    if fw_line_data_str.present?
      "Fish and Wildlife Transmission Date missing but F&W products found:\n#{fw_line_data_str}"
    end
  end
end
