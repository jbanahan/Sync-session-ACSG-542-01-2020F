# == Schema Information
#
# Table name: business_validation_rules
#
#  bcc_notification_recipients     :text
#  business_validation_template_id :integer
#  cc_notification_recipients      :text
#  created_at                      :datetime         not null
#  delete_pending                  :boolean
#  description                     :string(255)
#  disabled                        :boolean
#  fail_state                      :string(255)
#  group_id                        :integer
#  id                              :integer          not null, primary key
#  mailing_list_id                 :integer
#  message_pass                    :string(255)
#  message_review_fail             :string(255)
#  message_skipped                 :string(255)
#  name                            :string(255)
#  notification_recipients         :text
#  notification_type               :string(255)
#  rule_attributes_json            :text
#  subject_pass                    :string(255)
#  subject_review_fail             :string(255)
#  subject_skipped                 :string(255)
#  suppress_pass_notice            :boolean
#  suppress_review_fail_notice     :boolean
#  suppress_skipped_notice         :boolean
#  type                            :string(255)
#  updated_at                      :datetime         not null
#
# Indexes
#
#  template_id  (business_validation_template_id)
#

# DO NOT TOUCH THIS FILE. IT IS DEAD TO EVERYONE.
class ValidationRuleFieldComparison < BusinessValidationRule
  include ValidatesField

  def run_validation obj
    validate_field obj
  end
end
