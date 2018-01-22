# == Schema Information
#
# Table name: business_validation_rules
#
#  id                              :integer          not null, primary key
#  business_validation_template_id :integer
#  type                            :string(255)
#  name                            :string(255)
#  description                     :string(255)
#  fail_state                      :string(255)
#  rule_attributes_json            :text
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  group_id                        :integer
#  delete_pending                  :boolean
#  notification_type               :string(255)
#  notification_recipients         :text
#  disabled                        :boolean
#
# Indexes
#
#  template_id  (business_validation_template_id)
#

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
  def validation_expressions args=nil
    expressions = super(['regex', 'fail_if_matches', 'allow_blank'])
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
