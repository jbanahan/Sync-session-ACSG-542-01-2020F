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
