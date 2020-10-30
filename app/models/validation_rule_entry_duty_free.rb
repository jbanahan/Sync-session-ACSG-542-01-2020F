# -*- SkipSchemaAnnotations

# checks that entries with tariffs having specified SPI are duty free
class ValidationRuleEntryDutyFree < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation invoice_line
    spi = rule_attributes["spi_primary"]
    has_target_spi = invoice_line.commercial_invoice_tariffs.find { |t| t.spi_primary == spi }
    if has_target_spi
      unless invoice_line.total_duty.zero?
        stop_validation unless flag?("validate_all")
        return "Invoice line with SPI #{spi} should be duty free."
      end
    end
  end

end
