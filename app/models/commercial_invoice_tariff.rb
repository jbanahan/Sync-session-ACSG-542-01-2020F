# == Schema Information
#
# Table name: commercial_invoice_tariffs
#
#  additional_rate            :decimal(14, 7)
#  additional_rate_uom        :string(255)
#  advalorem_rate             :decimal(14, 7)
#  classification_qty_1       :decimal(12, 2)
#  classification_qty_2       :decimal(12, 2)
#  classification_qty_3       :decimal(12, 2)
#  classification_uom_1       :string(255)
#  classification_uom_2       :string(255)
#  classification_uom_3       :string(255)
#  commercial_invoice_line_id :integer
#  created_at                 :datetime         not null
#  duty_additional            :decimal(12, 2)
#  duty_advalorem             :decimal(12, 2)
#  duty_amount                :decimal(12, 2)
#  duty_other                 :decimal(12, 2)
#  duty_rate                  :decimal(4, 3)
#  duty_rate_description      :string(255)
#  duty_specific              :decimal(12, 2)
#  entered_value              :decimal(13, 2)
#  entered_value_7501         :integer
#  excise_amount              :decimal(11, 2)
#  excise_rate_code           :string(255)
#  gross_weight               :integer
#  gst_amount                 :decimal(11, 2)
#  gst_rate_code              :string(255)
#  hts_code                   :string(255)
#  id                         :integer          not null, primary key
#  integer                    :integer
#  quota_category             :integer
#  sima_amount                :decimal(11, 2)
#  sima_code                  :string(255)
#  special_authority          :string(255)
#  special_tariff             :boolean
#  specific_rate              :decimal(14, 7)
#  specific_rate_uom          :string(255)
#  spi_primary                :string(255)
#  spi_secondary              :string(255)
#  tariff_description         :string(255)
#  tariff_provision           :string(255)
#  updated_at                 :datetime         not null
#  value_for_duty_code        :string(255)
#
# Indexes
#
#  index_commercial_invoice_tariffs_on_commercial_invoice_line_id  (commercial_invoice_line_id)
#  index_commercial_invoice_tariffs_on_hts_code                    (hts_code)
#

class CommercialInvoiceTariff < ActiveRecord::Base
  include CustomFieldSupport

  attr_accessible :commercial_invoice_line_id, :hts_code, :duty_amount,
    :entered_value, :spi_primary, :spi_secondary, :classification_qty_1,
    :classification_uom_1, :classification_qty_2, :classification_uom_2,
    :classification_qty_3, :classification_uom_3, :gross_weight, :integer,
    :tariff_description, :created_at, :updated_at, :tariff_provision,
    :value_for_duty_code, :gst_amount, :gst_rate_code, :sima_amount, :excise_amount,
    :excise_rate_code, :duty_rate, :duty_rate_description, :quota_category,
    :special_authority, :sima_code, :entered_value_7501, :special_tariff,
    :duty_advalorem, :duty_specific, :duty_additional, :duty_other, :advalorem_rate,
    :specific_rate, :specific_rate_uom, :additional_rate, :additional_rate_uom

  belongs_to :commercial_invoice_line, inverse_of: :commercial_invoice_tariffs
  has_one :entry, through: :commercial_invoice_line
  has_many :commercial_invoice_lacey_components, dependent: :destroy, autosave: true, inverse_of: :commercial_invoice_tariff
  has_many :pga_summaries, dependent: :destroy, autosave: true, inverse_of: :commercial_invoice_tariff

  def canadian?
    value_for_duty_code.present?
  end

  def value_for_tax
    canadian? ? [self.entered_value, self.duty_amount, self.sima_amount, self.excise_amount].compact.sum : nil
  end

end
