class ValidationRuleOrderLineFieldFormat < BusinessValidationRule
  include ValidatesOrderLine
  include ValidatesFieldFormat

  def run_child_validation order
    validate_field_format(order) do |mf, val, regex|
      stop_validation
      "All #{mf.label} values do not match '#{regex}' format."
    end
  end
end