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

class ValidationRuleEntryInvoiceCooMatchesSpi < BusinessValidationRule

  #rule_attributes format: {"coo_1":"SPI_1", "coo_2":"SPI_2"...}
  def run_validation entry
    messages = []
    entry.commercial_invoice_lines.each do |cil|
      expected_spi = rule_attributes[cil.country_origin_code]
      cil.commercial_invoice_tariffs.each do |cit|
        messages << "#{cil.commercial_invoice.invoice_number} part #{cil.part_number}" unless expected_spi.blank? || expected_spi == cit.spi_primary 
      end
    end
    if messages.presence
      "The following invoices have a country-of-origin code that doesn't match its primary SPI:\n#{messages.join("\n")}"
    end
  end
end
