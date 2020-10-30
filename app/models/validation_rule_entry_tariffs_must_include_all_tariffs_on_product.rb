# -*- SkipSchemaAnnotations

class ValidationRuleEntryTariffsMustIncludeAllTariffsOnProduct < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation(invoice_line)
    part_number = invoice_line.part_number
    if part_number.blank?
      return error "Part number is empty for commercial invoice line"
    end
    system_code = rule_attributes['importer_system_code']
    country_id = country_id(invoice_line)
    product_hts = get_product_hts(part_number, system_code, country_id)
    entry_hts = invoice_line.commercial_invoice_tariffs.map(&:hts_code).reject(&:blank?)

    if !has_all_htss?(product_hts, entry_hts)
      missing_htss = product_hts - entry_hts
      return error("Part Number #{part_number} was missing tariff #{'number'.pluralize(missing_htss.count)} #{missing_htss.join(', ')}")
    else
      nil
    end
  end

  def has_all_htss?(product, entry)
    same = product & entry
    same == product
  end

  def get_product_hts(part_number, system_code, country_id)
    TariffRecord.
        joins("INNER JOIN classifications on classifications.id = tariff_records.classification_id").
        joins("INNER JOIN countries on countries.id = classifications.country_id").
        joins("INNER JOIN products on products.id = classifications.product_id").
        joins("INNER JOIN companies on products.importer_id = companies.id").
        joins("INNER JOIN custom_definitions on custom_definitions.cdef_uid = 'prod_part_number'").
        joins("INNER JOIN custom_values on custom_values.custom_definition_id = custom_definitions.id AND custom_values.customizable_type = 'Product' AND custom_values.customizable_id = products.id").
        where(["custom_values.string_value = ? AND companies.system_code = ? AND countries.id = ?", part_number, system_code, country_id]).
        pluck(:hts_1, :hts_2, :hts_3).flatten.compact
  end

  def country_id line
    @country_id ||= line.entry.import_country_id
  end

  def error(msg)
    stop_validation unless flag?("validate_all")
    msg
  end
end
