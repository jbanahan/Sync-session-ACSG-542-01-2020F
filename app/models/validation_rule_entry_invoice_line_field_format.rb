#run a field format validation on every invoice line on the entry and fail if ANY line fails the test
class ValidationRuleEntryInvoiceLineFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoiceLine
  include ValidatesFieldFormat

  def run_child_validation invoice_line
    validate_field_format(invoice_line) do |mf, val, regex, fail_if_matches|
      stop_validation unless has_flag?("validate_all")
      
      if fail_if_matches
        "Invoice # #{invoice_line.commercial_invoice.invoice_number} #{mf.label} value should not match '#{regex}' format."
      else
        "Invoice # #{invoice_line.commercial_invoice.invoice_number} #{mf.label} value '#{val}' does not match '#{regex}' format."
      end
    end
  end
end
