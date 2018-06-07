# -*- SkipSchemaAnnotations

class ValidationRuleBrokerInvoiceLineFieldFormat < BusinessValidationRule
  include ValidatesBrokerInvoiceLine
  include ValidatesFieldFormat

  def run_child_validation invoice_line
    validate_field_format(invoice_line) do |mf, val, reg, fail_if_matches|
      if fail_if_matches
        "Broker Invoice # #{invoice_line.broker_invoice.invoice_number} / Charge Code #{invoice_line.charge_code} #{mf.label} value should not match '#{reg}' format."
      else
        "Broker Invoice # #{invoice_line.broker_invoice.invoice_number} / Charge Code #{invoice_line.charge_code} #{mf.label} value '#{val}' does not match '#{reg}' format."
      end
    end
  end
end
