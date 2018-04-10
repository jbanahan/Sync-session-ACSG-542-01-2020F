# == Schema Information
#
# Table name: commercial_invoice_tariffs
#
#  classification_qty_1       :decimal(12, 2)
#  classification_qty_2       :decimal(12, 2)
#  classification_qty_3       :decimal(12, 2)
#  classification_uom_1       :string(255)
#  classification_uom_2       :string(255)
#  classification_uom_3       :string(255)
#  commercial_invoice_line_id :integer
#  created_at                 :datetime         not null
#  duty_amount                :decimal(12, 2)
#  duty_rate                  :decimal(4, 3)
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

  belongs_to :commercial_invoice_line, :touch=>true, :inverse_of=>:commercial_invoice_tariffs
  has_one :entry, through: :commercial_invoice_line
  has_many :commercial_invoice_lacey_components, dependent: :destroy, autosave: true
end
