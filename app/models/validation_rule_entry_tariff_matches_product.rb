# run a validation of part and hts vs Product database
# Options:
# - importer_id: company_id to use to look up product, defaults to same as the entry's importer_id
# - part_number_mask: allows extra characters in product database unique_identifier with part number inserted where the question mark is so part number '123' for mask 'CN-?' would look for product.unique_identifier = 'CN-123'
#
# All business rule setup (search criterion etc) is run against the Invoice Line NOT!!! against the Tariff.
class ValidationRuleEntryTariffMatchesProduct < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation invoice_line
    #collect all part/hts combinations
    part = invoice_line.part_number
    if part.blank?
      stop_validation
      return "Part number is empty for commercial invoice line."
    end
    unique_identifier = get_uid(part)
    entry = invoice_line.entry
    country_id = entry.import_country_id
    importer_id = get_importer_id(entry)
    good_hts_vals = TariffRecord.joins(:classification=>:product).
      where("products.importer_id = ?",importer_id).
      where("classifications.country_id = ?",country_id).
      where("products.unique_identifier = ?",unique_identifier).
      pluck(:hts_1)
    invoice_line.commercial_invoice_tariffs.each do |ct|
      hts = ct.hts_code
      if hts.blank?
        stop_validation
        return "HTS code is blank for line." 
      end
      if !good_hts_vals.include?(hts.gsub(/\./,'').strip)
        stop_validation
        return "Invalid HTS #{ct.hts_code} for part #{part}"
      end
    end
    return nil
  end

  private
  def get_uid part_number
    mask = rule_attributes['part_number_mask']
    return part_number if mask.blank?
    return mask.gsub(/\?/,part_number)
  end
  def get_importer_id entry
    id = entry.importer_id
    override = rule_attributes['importer_id']
    id = override unless override.blank?
    return id
  end
end