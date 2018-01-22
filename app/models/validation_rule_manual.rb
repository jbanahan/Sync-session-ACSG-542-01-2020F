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

#indicates a manual check is needed
class ValidationRuleManual < BusinessValidationRule
  def run_validation obj
    "Manual review required."
  end
end
