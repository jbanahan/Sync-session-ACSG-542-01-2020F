class ValidationRuleOrderLineFieldFormat < BusinessValidationRule
  include ValidatesOrderLine
  include ValidatesFieldFormat

  def run_child_validation order
    message = validate_field_format(order) do |mf, val, regex, fail_if_matches|
      if fail_if_matches
        "At least one #{mf.label} value matches '#{regex}' format."
      else
        "All #{mf.label} values do not match '#{regex}' format."
      end
    end
    stop_validation if !message.blank?
    return message
  end
end
