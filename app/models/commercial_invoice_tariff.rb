# == Schema Information
#
# Table name: commercial_invoice_tariffs
#
#  id                         :integer          not null, primary key
#  commercial_invoice_line_id :integer
#  hts_code                   :string(255)
#  duty_amount                :decimal(12, 2)
#  entered_value              :decimal(13, 2)
#  spi_primary                :string(255)
#  spi_secondary              :string(255)
#  classification_qty_1       :decimal(12, 2)
#  classification_uom_1       :string(255)
#  classification_qty_2       :decimal(12, 2)
#  classification_uom_2       :string(255)
#  classification_qty_3       :decimal(12, 2)
#  classification_uom_3       :string(255)
#  gross_weight               :integer
#  integer                    :integer
#  tariff_description         :string(255)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  tariff_provision           :string(255)
#  value_for_duty_code        :string(255)
#  gst_rate_code              :string(255)
#  gst_amount                 :decimal(11, 2)
#  sima_amount                :decimal(11, 2)
#  excise_amount              :decimal(11, 2)
#  excise_rate_code           :string(255)
#  duty_rate                  :decimal(4, 3)
#  quota_category             :integer
#  special_authority          :string(255)
#  sima_code                  :string(255)
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
