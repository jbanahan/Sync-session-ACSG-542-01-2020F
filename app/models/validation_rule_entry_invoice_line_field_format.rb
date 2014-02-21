#run a field format validation on every invoice line on the entry and fail if ANY line fails the test
class ValidationRuleEntryInvoiceLineFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def setup_validation
    @model_field = ModelField.find_by_uid self.rule_attributes['model_field_uid']
  end

  def run_child_validation invoice_line
    attrs = self.rule_attributes
    regex = attrs['regex']
    mf = ModelField.find_by_uid self.rule_attributes['model_field_uid']
    line_value = @model_field.process_export(invoice_line, nil, true)

    message = nil
    unless attrs['allow_blank'] && line_value.blank?
      if !line_value.to_s.match(regex)
        message = "All #{@model_field.label} values do not match '#{regex}' format."
        stop_validation
      end
    end

    message
  end
end
