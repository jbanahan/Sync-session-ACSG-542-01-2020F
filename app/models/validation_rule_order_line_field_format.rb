class ValidationRuleOrderLineFieldFormat < BusinessValidationRule
  include ValidatesOrderLine
  include ValidatesFieldFormat

  def run_child_validation order
    message = validate_field_format(order) do |mf, val, regex|
      "All #{mf.label} values do not match '#{regex}' format."
    end
    stop_validation if !message.blank?
    return message
  end
end
