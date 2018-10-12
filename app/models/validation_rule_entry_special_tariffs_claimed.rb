# -*- SkipSchemaAnnotations

# This rule errors every time a special tariff is utilized.  The intent is to flag the entry for review
# any time a special tariff is used.
# The rule should probably be set up to limit to only distinct special rule types (ie. MTB, 301, etc.).
class ValidationRuleEntrySpecialTariffsClaimed < BusinessValidationRule
  include ValidatesCommercialInvoiceLine
  include ValidationRuleEntrySpecialTariffsSupport

  def run_child_validation invoice_line
    # We need to be looking up the special tariffs, so make sure the special tariff hash is keyed according to the 
    @special_tariffs_hash ||= special_tariffs(invoice_line.commercial_invoice.entry, use_special_hts_number: true)
    validate_special_tariff_claimed(invoice_line.commercial_invoice, invoice_line, @special_tariffs_hash)
  end

  def validate_special_tariff_claimed invoice, invoice_line, special_tariffs_hash
    errors = []
    tariffs_used = invoice_line.commercial_invoice_tariffs.map &:hts_code
    
    tariffs_used.each do |hts_number|
      # If the tariff number is a special tariff, then determine what the corresponding "standard" tariffs are for that number
      # and make sure one of those was also used here.
      special_tariffs = special_tariffs_hash.tariffs_for invoice_line.country_origin_code, hts_number

      if special_tariffs.length > 0
        errors << "Invoice # #{invoice.invoice_number} / Line # #{invoice_line.line_number} / HTS # #{hts_number.hts_format} is a #{special_tariffs[0].special_tariff_type} HTS #."
      end
    end

    if errors.length > 0
      errors.insert(0, "Please review the following lines to ensure the special tariffs were applied correctly:")
    end
    
    errors
  end
  
end