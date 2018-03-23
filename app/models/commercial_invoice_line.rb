# == Schema Information
#
# Table name: commercial_invoice_lines
#
#  id                     :integer          not null, primary key
#  part_number            :string(255)
#  line_number            :integer
#  po_number              :string(255)
#  unit_of_measure        :string(255)
#  commercial_invoice_id  :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  value                  :decimal(11, 2)
#  drawback_qty           :decimal(11, 2)
#  quantity               :decimal(12, 3)
#  mid                    :string(255)
#  country_origin_code    :string(255)
#  charges                :decimal(11, 2)
#  country_export_code    :string(255)
#  related_parties        :boolean
#  vendor_name            :string(255)
#  volume                 :decimal(11, 2)
#  computed_value         :decimal(13, 2)
#  computed_adjustments   :decimal(13, 2)
#  computed_net_value     :decimal(13, 2)
#  mpf                    :decimal(11, 2)
#  hmf                    :decimal(11, 2)
#  cotton_fee             :decimal(11, 2)
#  state_export_code      :string(255)
#  state_origin_code      :string(255)
#  unit_price             :decimal(12, 3)
#  department             :string(255)
#  prorated_mpf           :decimal(11, 2)
#  contract_amount        :decimal(12, 2)
#  add_case_number        :string(255)
#  add_bond               :boolean
#  add_duty_amount        :decimal(12, 2)
#  add_case_value         :decimal(12, 2)
#  add_case_percent       :decimal(5, 2)
#  cvd_case_number        :string(255)
#  cvd_bond               :boolean
#  cvd_duty_amount        :decimal(12, 2)
#  cvd_case_value         :decimal(12, 2)
#  cvd_case_percent       :decimal(5, 2)
#  customer_reference     :string(255)
#  adjustments_amount     :decimal(12, 3)
#  value_foreign          :decimal(11, 2)
#  currency               :string(255)
#  customs_line_number    :integer
#  product_line           :string(255)
#  visa_number            :string(255)
#  visa_quantity          :decimal(12, 3)
#  visa_uom               :string(255)
#  store_name             :string(255)
#  subheader_number       :integer
#  container_id           :integer
#  fda_review_date        :datetime
#  fda_hold_date          :datetime
#  fda_release_date       :datetime
#  first_sale             :boolean
#  value_appraisal_method :string(255)
#  non_dutiable_amount    :decimal(13, 2)
#  other_fees             :decimal(11, 2)
#  miscellaneous_discount :decimal(12, 2)
#
# Indexes
#
#  index_commercial_invoice_lines_on_commercial_invoice_id  (commercial_invoice_id)
#  index_commercial_invoice_lines_on_container_id           (container_id)
#  index_commercial_invoice_lines_on_part_number            (part_number)
#

class CommercialInvoiceLine < ActiveRecord::Base
  belongs_to :commercial_invoice, :inverse_of=>:commercial_invoice_lines, :touch=>true
  has_one :entry, :through => :commercial_invoice
  has_many :commercial_invoice_tariffs, :dependent=>:destroy, :autosave=>true
  has_many :change_records, :as => :recordable
  belongs_to :container
  
  include CustomFieldSupport
  include LinesSupport

  def duty_plus_fees_amount
    BigDecimal.new([self.total_duty, self.total_fees].compact.sum)
  end

  def total_duty
    BigDecimal.new(self.commercial_invoice_tariffs.map(&:duty_amount).compact.sum)
  end

  def total_fees
    [prorated_mpf, hmf, cotton_fee, other_fees].compact.sum
  end

  def total_entered_value
    BigDecimal.new(self.commercial_invoice_tariffs.map(&:entered_value).compact.sum)
  end

  def duty_plus_fees_add_cvd_amounts
    self.duty_plus_fees_amount + ([add_duty_amount, cvd_duty_amount]).compact.sum
  end

  def first_sale_savings
    return BigDecimal("0") if contract_amount.try(:zero?)

    # If we don't have a contract amount (.ie it's nil), then any calculation based off it should be nil too
    cit = commercial_invoice_tariffs.first
    if contract_amount.nil? || cit.nil?
      nil
    else
      ((contract_amount - value) * (cit.duty_amount / cit.entered_value)).round(2)
    end
  end

  def first_sale_difference
    return BigDecimal("0") if contract_amount.try(:zero?)

    # If we don't have a contract amount (.ie it's nil), then any calculation based off it should be nil too
    contract_amount.nil? ? nil : (contract_amount - value).round(2)
  end

  def first_sale_unit_price
    # If we don't have a contract amount (.ie it's nil), then any calculation based off it should be nil too
    (contract_amount.nil? || quantity.nil? || quantity.zero?) ? nil : (contract_amount / quantity).round(2)
  end
end
