class ValidationRuleEntryInvoiceCooMatchesSpi < BusinessValidationRule

  #rule_attributes format: {"coo_1":"SPI_1", "coo_2":"SPI_2"...}
  def run_validation entry
    messages = []
    entry.commercial_invoice_lines.each do |cil|
      expected_spi = rule_attributes[cil.country_origin_code]
      cil.commercial_invoice_tariffs.each do |cit|
        messages << "#{cil.commercial_invoice.invoice_number} part #{cil.part_number}" unless expected_spi.blank? || expected_spi == cit.spi_primary 
      end
    end
    if messages.presence
      "The following invoices have a country-of-origin code that doesn't match its primary SPI:\n#{messages.join("\n")}"
    end
  end
end