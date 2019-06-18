# -*- SkipSchemaAnnotations

#run a field format validation on every invoice line on the entry and fail if ANY line fails the test
class ValidationRuleProductClassificationFieldFormat < BusinessValidationRule
  include ValidatesClassification
  include ValidatesFieldFormat

  def run_child_validation classification
    validate_field_format(classification) do |mf, val, regex, fail_if_matches|
      stop_validation
      if fail_if_matches
        "At least one #{mf.label} value matches '#{regex}' format."
      else
        "All #{mf.label} values do not match '#{regex}' format."
      end
    end
  end
end
