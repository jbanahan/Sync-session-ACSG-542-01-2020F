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

class ValidationRuleEntryInvoiceLineMatchesPo < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation invoice_line
    order = find_order get_importer_id(invoice_line), invoice_line.po_number
    return order.nil? ? "No Order found for PO # #{invoice_line.po_number}." : nil
  end

  private
    def find_order importer_id, customer_order_number
      # Involving caching because multiple invoice lines may be hooked to same PO.
      @cache ||= Hash.new do |order_hash, key|
        order_hash[key] = Order.where(importer_id: importer_id, customer_order_number: key).first
      end

      @cache[customer_order_number]
    end

    def get_importer_id invoice_line
      @importer_id ||= rule_attributes["importer_id"].present? ? rule_attributes["importer_id"].to_i : invoice_line.entry.importer_id

      @importer_id
    end

end
