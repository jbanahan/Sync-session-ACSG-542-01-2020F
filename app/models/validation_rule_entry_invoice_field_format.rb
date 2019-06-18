# -*- SkipSchemaAnnotations

class ValidationRuleEntryInvoiceFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoice
  include ValidatesFieldFormat

  def run_child_validation invoice
    validate_field_format(invoice) do |mf, val, regex, fail_if_matches|
      stop_validation unless has_flag?("validate_all")
      if fail_if_matches
        "Invoice #{invoice.invoice_number} #{mf.label} value should not match '#{regex}' format."
      else
        "Invoice #{invoice.invoice_number} #{mf.label} value '#{val}' does not match '#{regex}' format."
      end
    end
  end
end
