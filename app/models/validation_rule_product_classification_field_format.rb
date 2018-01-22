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
