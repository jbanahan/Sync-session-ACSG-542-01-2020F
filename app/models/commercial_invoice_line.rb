# == Schema Information
#
# Table name: commercial_invoice_lines
#
#  add_bond                   :boolean
#  add_case_number            :string(255)
#  add_case_percent           :decimal(5, 2)
#  add_case_value             :decimal(12, 2)
#  add_duty_amount            :decimal(12, 2)
#  add_to_make_amount         :decimal(12, 2)
#  adjustments_amount         :decimal(12, 3)
#  agriculture_license_number :string(255)
#  cash_discount              :decimal(12, 2)
#  charges                    :decimal(11, 2)
#  commercial_invoice_id      :integer
#  computed_adjustments       :decimal(13, 2)
#  computed_net_value         :decimal(13, 2)
#  computed_value             :decimal(13, 2)
#  container_id               :integer
#  contract_amount            :decimal(12, 2)
#  cotton_fee                 :decimal(11, 2)
#  country_export_code        :string(255)
#  country_origin_code        :string(255)
#  created_at                 :datetime         not null
#  currency                   :string(255)
#  customer_reference         :string(255)
#  customs_line_number        :integer
#  cvd_bond                   :boolean
#  cvd_case_number            :string(255)
#  cvd_case_percent           :decimal(5, 2)
#  cvd_case_value             :decimal(12, 2)
#  cvd_duty_amount            :decimal(12, 2)
#  department                 :string(255)
#  drawback_qty               :decimal(11, 2)
#  entered_value_7501         :integer
#  fda_hold_date              :datetime
#  fda_release_date           :datetime
#  fda_review_date            :datetime
#  first_sale                 :boolean
#  freight_amount             :decimal(12, 2)
#  hmf                        :decimal(11, 2)
#  id                         :integer          not null, primary key
#  line_number                :integer
#  mid                        :string(255)
#  miscellaneous_discount     :decimal(12, 2)
#  mpf                        :decimal(11, 2)
#  non_dutiable_amount        :decimal(13, 2)
#  other_amount               :decimal(12, 2)
#  other_fees                 :decimal(11, 2)
#  part_number                :string(255)
#  po_number                  :string(255)
#  product_line               :string(255)
#  prorated_mpf               :decimal(11, 2)
#  psc_date                   :datetime
#  psc_reason_code            :string(255)
#  quantity                   :decimal(12, 3)
#  related_parties            :boolean
#  state_export_code          :string(255)
#  state_origin_code          :string(255)
#  store_name                 :string(255)
#  subheader_number           :integer
#  unit_of_measure            :string(255)
#  unit_price                 :decimal(12, 3)
#  updated_at                 :datetime         not null
#  value                      :decimal(11, 2)
#  value_appraisal_method     :string(255)
#  value_foreign              :decimal(11, 2)
#  vendor_name                :string(255)
#  visa_number                :string(255)
#  visa_quantity              :decimal(12, 3)
#  visa_uom                   :string(255)
#  volume                     :decimal(11, 2)
#
# Indexes
#
#  index_commercial_invoice_lines_on_commercial_invoice_id  (commercial_invoice_id)
#  index_commercial_invoice_lines_on_container_id           (container_id)
#  index_commercial_invoice_lines_on_part_number            (part_number)
#

class CommercialInvoiceLine < ActiveRecord::Base
  attr_accessible :add_bond, :add_case_number, :add_case_percent,
    :add_case_value, :add_duty_amount, :add_to_make_amount, :adjustments_amount,
    :agriculture_license_number, :cash_discount, :charges, :commercial_invoice_id,
    :computed_adjustments, :computed_net_value, :computed_value, :container_id,
    :container, :contract_amount, :cotton_fee, :country_export_code, :country_origin_code,
    :currency, :customer_reference, :customs_line_number, :cvd_bond,
    :cvd_case_number, :cvd_case_percent, :cvd_case_value, :cvd_duty_amount,
    :department, :drawback_qty, :entered_value_7501, :fda_hold_date, :fda_release_date,
    :fda_review_date, :first_sale, :freight_amount, :hmf, :line_number, :mid,
    :miscellaneous_discount, :mpf, :non_dutiable_amount, :other_amount,
    :other_fees, :part_number, :po_number, :product_line, :prorated_mpf,
    :psc_date, :psc_reason_code, :quantity, :related_parties, :state_export_code,
    :state_origin_code, :store_name, :subheader_number, :unit_of_measure,
    :unit_price, :value, :value_appraisal_method, :value_foreign, :vendor_name,
    :visa_number, :visa_quantity, :visa_uom, :volume, :commercial_invoice_tariffs

  belongs_to :commercial_invoice, inverse_of: :commercial_invoice_lines
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

  def total_supplemental_tariff meth
    BigDecimal.new(self.supplemental_tariffs.map(&meth).compact.sum)
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

  def supplemental_tariffs
    self.commercial_invoice_tariffs.select { |t| t.hts_code =~ /\A99/ }
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

  # Cumulative sum of value_for_tax for commercial invoice tariffs associated
  #  with a given commercial invoice line
  def value_for_tax
    values = self.commercial_invoice_tariffs.map(&:value_for_tax).compact
    values.length == 0 ? nil : values.sum
  end

  def first_sale_unit_price
    # If we don't have a contract amount (.ie it's nil), then any calculation based off it should be nil too
    (contract_amount.nil? || quantity.nil? || quantity.zero?) ? nil : (contract_amount / quantity).round(2)
  end

  # Returns the first non-zero gross weight from the tariffs, defaulting to zero (rather than nil) if no
  # are found.
  def gross_weight
    BigDecimal.new(self.commercial_invoice_tariffs.map(&:gross_weight).compact.find { |t| t > 0 } || 0)
  end
end
