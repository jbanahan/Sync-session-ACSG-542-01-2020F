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

class ValidationRuleEntryInvoiceFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoice
  include ValidatesFieldFormat

  def run_child_validation invoice
    validate_field_format(invoice) do |mf, val, regex, fail_if_matches|
      stop_validation unless has_flag?("validate_all")
      if fail_if_matches
        "Invoice #{invoice.invoice_number} #{mf.label} value should not match '#{regex}' format."
      else
        "Invoice #{invoice.invoice_number} #{mf.label} value '#{val}' does not match '#{regex}' format."
      end
    end
  end
end
