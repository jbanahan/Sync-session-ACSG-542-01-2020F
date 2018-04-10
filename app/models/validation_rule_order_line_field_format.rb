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
#  name                            :string(255)
#  notification_recipients         :text
#  notification_type               :string(255)
#  rule_attributes_json            :text
#  type                            :string(255)
#  updated_at                      :datetime         not null
#
# Indexes
#
#  template_id  (business_validation_template_id)
#

class ValidationRuleOrderLineFieldFormat < BusinessValidationRule
  include ValidatesOrderLine
  include ValidatesFieldFormat

  def run_child_validation order_line
    validate_field_format(order_line) do |mf, val, regex, fail_if_matches|
      stop_validation unless has_flag?("validate_all")

      if fail_if_matches
        "At least one #{mf.label} value matches '#{regex}' format."
      else
        "All #{mf.label} values do not match '#{regex}' format."
      end
    end
  end
end
