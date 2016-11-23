# This class DOES NOT support the multiple field validation aspect of ValidatesFieldFormat.
# 
# If you set up multiple model fields, the validation will raise an error
class ValidationRuleAnyEntryInvoiceLineHasFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoiceLine
  include ValidatesFieldFormat  

  def run_validation entity
    @matched = false
    # We shouldn't be getting any actual messages back here, instead we're letting the 
    # validation go through all the lines and then just checking the matched flag to see if
    # any lines actually matched.
    super

    return nil if @matched
    
    if rule_attribute('fail_if_matches')
      "At least one #{model_field.label} value must NOT match '#{match_expression}' format."
    else
      "At least one #{model_field.label} value must match '#{match_expression}' format."
    end
  end

  def run_child_validation invoice_line
    message = validate_field_format(invoice_line, yield_matches: true, yield_failures: false) do |mf, val, regex|
      @matched = true
      stop_validation
    end
    nil
  end

  # This validation doesn't work with multiple model fields set up...
  def validation_expressions
    expressions = super
    raise "Using multiple model fields is not supported with this business rule." if expressions.size > 1
    mf = expressions.keys.first

    {mf => expressions[mf]}
  end

  def model_field
    validation_expressions.keys.first
  end

  def match_expression
    validation_expressions[model_field]['regex']
  end
end