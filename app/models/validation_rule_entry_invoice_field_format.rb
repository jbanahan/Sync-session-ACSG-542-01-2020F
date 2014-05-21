class ValidationRuleEntryInvoiceFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoice
  include ValidatesFieldFormat

  def run_child_validation invoice
    validate_field_format(invoice) do |mf, val, regex|
      stop_validation
      "All #{mf.label} values do not match '#{regex}' format."
    end
  end
end