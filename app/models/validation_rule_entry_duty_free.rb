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

#checks that entries with tariffs having specified SPI are duty free
class ValidationRuleEntryDutyFree < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation invoice_line
    spi = rule_attributes["spi_primary"]
    has_target_spi = invoice_line.commercial_invoice_tariffs.find { |t| t.spi_primary == spi }
    if has_target_spi
      unless invoice_line.total_duty.zero?
        stop_validation unless has_flag?("validate_all")
        return "Invoice line with SPI #{spi} should be duty free."
      end
    end
  end

end
