class ValidationRuleOrderLineProductFieldFormat < BusinessValidationRule
  include ValidatesOrderLine
  include ValidatesFieldFormat

  def run_child_validation order_line
    p = order_line.product
    if p.nil?
      return "Line #{order_line.line_number} does not have a product assigned."
    end
    validate_field_format(p) do |mf, val, regex|
      "All #{mf.label} value does not match '#{regex}' format for Product #{p.unique_identifier}."
    end
  end
end