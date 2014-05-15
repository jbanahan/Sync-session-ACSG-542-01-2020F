#run a field format validation on every invoice line on the entry and fail if ANY line fails the test
class ValidationRuleEntryInvoiceLineFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoiceLine
  include ValidatesFieldFormat

  def run_child_validation invoice_line
    validate_field_format(invoice_line) do |mf, val, regex|
      stop_validation
      "All #{mf.label} values do not match '#{regex}' format."
    end
  end
end
