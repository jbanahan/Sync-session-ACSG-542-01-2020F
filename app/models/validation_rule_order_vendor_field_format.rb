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

class ValidationRuleOrderVendorFieldFormat < BusinessValidationRule
  include ValidatesFieldFormat

  def run_validation ord
    vend = ord.vendor
    if vend.nil?
      return "Vendor must be set."
    end
    validate_field_format(vend) do |mf, val, regex, fail_if_matches|
      if fail_if_matches
        "At least one #{mf.label} value matches '#{regex}' format for Vendor #{vend.name}."
      else
        "All #{mf.label} value does not match '#{regex}' format for Vendor #{vend.name}."
      end
    end
  end
end
