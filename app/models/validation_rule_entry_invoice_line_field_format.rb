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

#run a field format validation on every invoice line on the entry and fail if ANY line fails the test
class ValidationRuleEntryInvoiceLineFieldFormat < BusinessValidationRule
  include ValidatesCommercialInvoiceLine
  include ValidatesFieldFormat

  def run_child_validation invoice_line
    validate_field_format(invoice_line) do |mf, val, regex, fail_if_matches|
      stop_validation unless has_flag?("validate_all")
      
      if fail_if_matches
        "Invoice # #{invoice_line.commercial_invoice.invoice_number} / Line # #{invoice_line.line_number} #{mf.label} value should not match '#{regex}' format."
      else
        "Invoice # #{invoice_line.commercial_invoice.invoice_number} / Line # #{invoice_line.line_number} #{mf.label} value '#{val}' does not match '#{regex}' format."
      end
    end
  end
end
