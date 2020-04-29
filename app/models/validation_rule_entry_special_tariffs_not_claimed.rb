# -*- SkipSchemaAnnotations

# This rule validates that if there are any tariff numbers used on the entry that have special
# tariffs set up in the SpecialTariffCrossReference table that those special tariff numbers are
# also present on the invoice line.
class ValidationRuleEntrySpecialTariffsNotClaimed < BusinessValidationRule
  include ValidatesCommercialInvoiceLine
  include ValidationRuleEntrySpecialTariffsSupport

  def run_child_validation invoice_line
    @special_tariffs_hash ||= special_tariffs(invoice_line.commercial_invoice.entry)
    validate_special_tariff_not_claimed(invoice_line.commercial_invoice, invoice_line, @special_tariffs_hash)
  end

  def validate_special_tariff_not_claimed invoice, invoice_line, special_tariffs_hash
    errors = []
    tariffs_used = invoice_line.commercial_invoice_tariffs.map &:hts_code

    tariffs_used.each do |hts_number|
      # Skip any lines that are part of the exclusion set
      next if tariff_exceptions.include?(hts_number)
      # Skip any lines that are NOT part of the inclusion set (if it's being used)
      next if tariff_inclusions.size > 0 && !tariff_inclusions.include?(hts_number)

      special_tariffs = special_tariffs_hash.tariffs_for invoice_line.country_origin_code, hts_number

      if special_tariffs.length > 0
        special_tariffs.each do |special_tariff|
          if !tariffs_used.include? special_tariff.special_hts_number
            errors << "Invoice # #{invoice.invoice_number} / Line # #{invoice_line.line_number} / HTS # #{hts_number.hts_format} may be able to claim #{special_tariff.special_tariff_type} HTS # #{special_tariff.special_hts_number.hts_format}."
          end
        end
      end
    end

    errors
  end
end