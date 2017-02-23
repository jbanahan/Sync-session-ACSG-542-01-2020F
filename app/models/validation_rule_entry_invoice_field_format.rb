class ValidationRuleEntryInvoiceFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoice
  include ValidatesFieldFormat

  def run_child_validation invoice
    validate_field_format(invoice) do |mf, val, regex, fail_if_matches|
      stop_validation unless has_flag?("validate_all")
      if fail_if_matches
        "At least one #{mf.label} value matches '#{regex}' format."
      else
        "All #{mf.label} values do not match '#{regex}' format."
      end
    end
  end
end