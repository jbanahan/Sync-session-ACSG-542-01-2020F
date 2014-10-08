#run a field format validation on every invoice line on the entry and fail if ANY line fails the test
class ValidationRuleAnyEntryInvoiceLineHasFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoiceLine
  include ValidatesFieldFormat  

  def run_validation entity
    @matched = false
    # We shouldn't be getting any actual messages back here, instead we're letting the 
    # validation go through all the lines and then just checking the matched flag to see if
    # any lines actually matched.
    super

    @matched ? nil : "At least one #{model_field.label} value must match '#{match_expression}' format."
  end

  def run_child_validation invoice_line
    message = validate_field_format(invoice_line, yield_matches: true, yield_failures: false) do |mf, val, regex|
      @matched = true
      stop_validation
    end
    nil
  end


end