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

class ValidationRuleEntryInvoiceValueMatchesDaPercent < BusinessValidationRule
  
  include ValidatesCommercialInvoice

  def run_child_validation invoice
    da_total = invoice.commercial_invoice_lines.inject(0) do |acc, nxt| 
      adj = nxt.adjustments_amount
      adj ? acc + adj : acc
    end    
    target_rate = rule_attributes["adjustment_rate"]
    calc_rate = (BigDecimal(100) * da_total) / invoice.invoice_value_foreign
    unless (target_rate - calc_rate).abs < 0.01
      "Invoice #{invoice.invoice_number} has a DA amount that is #{sprintf('%.2f', calc_rate)}% of the total, expected #{sprintf('%.2f', target_rate)}%."
    end
  end
end
