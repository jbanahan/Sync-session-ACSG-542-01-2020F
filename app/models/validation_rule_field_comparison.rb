# -*- SkipSchemaAnnotations

# DO NOT TOUCH THIS FILE. IT IS DEAD TO EVERYONE.
class ValidationRuleFieldComparison < BusinessValidationRule
  include ValidatesField

  def run_validation obj
    validate_field obj
  end
end
