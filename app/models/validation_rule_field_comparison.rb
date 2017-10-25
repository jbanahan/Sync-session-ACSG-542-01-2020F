class ValidationRuleFieldComparison < BusinessValidationRule
  include ValidatesField

  def run_validation obj
    validate_field obj
  end
end