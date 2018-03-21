# == Schema Information
#
# Table name: invoice_lines
#
#  id                 :integer          not null, primary key
#  air_sea_discount   :decimal(12, 2)
#  country_export_id  :integer
#  country_origin_id  :integer
#  department         :string(255)
#  early_pay_discount :decimal(12, 2)
#  first_sale         :boolean
#  fish_wildlife      :boolean
#  gross_weight       :integer
#  gross_weight_uom   :string(255)
#  hts_number         :string(255)
#  invoice_id         :integer
#  line_number        :integer
#  mid                :string(255)
#  middleman_charge   :decimal(12, 2)
#  net_weight         :decimal(12, 2)
#  net_weight_uom     :string(255)
#  order_id           :integer
#  order_line_id      :integer
#  part_description   :string(255)
#  part_number        :string(255)
#  pieces             :decimal(13, 4)
#  po_number          :string(255)
#  product_id         :integer
#  quantity           :decimal(12, 3)
#  quantity_uom       :string(255)
#  trade_discount     :decimal(12, 2)
#  unit_price         :decimal(12, 3)
#  value_domestic     :decimal(13, 2)
#  value_foreign      :decimal(11, 2)
#  variant_id         :integer
#  volume             :decimal(11, 2)
#  volume_uom         :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_invoice_lines_on_invoice_id  (invoice_id)
#

class InvoiceLine < ActiveRecord::Base
  belongs_to :invoice_line
  belongs_to :country_export, :class_name => "Country"
  belongs_to :country_origin, :class_name => "Country"
  belongs_to :order
  belongs_to :order_line
  belongs_to :product
  belongs_to :variant

  validates :line_number, presence: true
end
