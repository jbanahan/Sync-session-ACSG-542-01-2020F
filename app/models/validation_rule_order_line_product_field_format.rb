# == Schema Information
#
# Table name: business_validation_rules
#
#  business_validation_template_id :integer
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

class ValidationRuleOrderLineProductFieldFormat < BusinessValidationRule
  include ValidatesOrderLine
  include ValidatesFieldFormat

  def run_child_validation order_line
    p = order_line.product
    if p.nil?
      return "Line #{order_line.line_number} does not have a product assigned."
    end
    validate_field_format(p) do |mf, val, regex, fail_if_matches|
      if fail_if_matches
        "At least one #{mf.label} value matches '#{regex}' format for Product #{p.unique_identifier}."
      else
        "All #{mf.label} value does not match '#{regex}' format for Product #{p.unique_identifier}."
      end
    end
  end
end
