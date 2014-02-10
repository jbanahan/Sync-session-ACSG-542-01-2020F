#indicates a manual check is needed
class ValidationRuleManual < BusinessValidationRule
  def run_validation obj
    "Manual review required."
  end
end
