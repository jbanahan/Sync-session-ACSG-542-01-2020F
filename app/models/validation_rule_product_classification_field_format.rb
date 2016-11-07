#run a field format validation on every invoice line on the entry and fail if ANY line fails the test
class ValidationRuleProductClassificationFieldFormat < BusinessValidationRule
  include ValidatesClassification
  include ValidatesFieldFormat

  def run_child_validation classification
    validate_field_format(classification) do |mf, val, regex|
      stop_validation
      "All #{mf.label} values do not match '#{regex}' format."
    end
  end
end
