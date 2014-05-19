#run a field format validation on every invoice tariff on the entry and fail if ANY tariff fails the test
# All business rule setup (search criterion etc) is run against the Invoice Line NOT!!! against the Tariff.
class ValidationRuleEntryInvoiceLineTariffFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoiceLine
  include ValidatesFieldFormat

  def run_child_validation invoice_line
    stop = false
    message = nil
    invoice_line.commercial_invoice_tariffs.each do |tariff|
      break if stop
      message = validate_field_format(tariff) do |mf, val, regex|
        stop = true
        stop_validation
        "All #{mf.label} values do not match '#{regex}' format."
      end
    end

    message
  end
end