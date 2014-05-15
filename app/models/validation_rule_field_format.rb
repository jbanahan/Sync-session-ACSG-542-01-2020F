class ValidationRuleFieldFormat < BusinessValidationRule
  include ValidatesFieldFormat

  def run_validation obj
    validate_field_format obj
  end
end
