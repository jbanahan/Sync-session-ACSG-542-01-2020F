# -*- SkipSchemaAnnotations

class ValidationRuleBrokerInvoiceFieldFormat < BusinessValidationRule
  include ValidatesBrokerInvoice
  include ValidatesFieldFormat

  def run_child_validation invoice
      validate_field_format(invoice) do |mf, val, reg, fail_if_matches|
        if fail_if_matches
          "Broker Invoice # #{invoice.invoice_number} #{mf.label} value should not match '#{reg}' format."
        else
          "Broker Invoice # #{invoice.invoice_number} #{mf.label} value '#{val}' does not match '#{reg}' format."
        end
      end
  end
end
