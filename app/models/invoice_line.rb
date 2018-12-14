# == Schema Information
#
# Table name: invoice_lines
#
#  air_sea_discount      :decimal(12, 2)
#  carrier_code          :string(255)
#  cartons               :integer
#  container_number      :string(255)
#  country_export_id     :integer
#  country_origin_id     :integer
#  created_at            :datetime         not null
#  customs_quantity      :decimal(12, 2)
#  customs_quantity_uom  :string(255)
#  department            :string(255)
#  early_pay_discount    :decimal(12, 2)
#  first_sale            :boolean
#  fish_wildlife         :boolean
#  gross_weight          :integer
#  gross_weight_uom      :string(255)
#  hts_number            :string(255)
#  id                    :integer          not null, primary key
#  invoice_id            :integer
#  line_number           :integer
#  master_bill_of_lading :string(255)
#  mid                   :string(255)
#  middleman_charge      :decimal(12, 2)
#  net_weight            :decimal(12, 2)
#  net_weight_uom        :string(255)
#  order_id              :integer
#  order_line_id         :integer
#  part_description      :string(255)
#  part_number           :string(255)
#  pieces                :decimal(13, 4)
#  po_line_number        :string(255)
#  po_number             :string(255)
#  product_id            :integer
#  quantity              :decimal(12, 3)
#  quantity_uom          :string(255)
#  related_parties       :boolean
#  spi                   :string(255)
#  spi2                  :string(255)
#  trade_discount        :decimal(12, 2)
#  unit_price            :decimal(12, 3)
#  updated_at            :datetime         not null
#  value_domestic        :decimal(13, 2)
#  value_foreign         :decimal(11, 2)
#  variant_id            :integer
#  volume                :decimal(11, 2)
#  volume_uom            :string(255)
#
# Indexes
#
#  index_invoice_lines_on_invoice_id   (invoice_id)
#  index_invoice_lines_on_part_number  (part_number)
#  index_invoice_lines_on_po_number    (po_number)
#

class InvoiceLine < ActiveRecord::Base
  include DefaultLineNumberSupport
  
  belongs_to :invoice, inverse_of: :invoice_lines
  belongs_to :country_export, class_name: "Country"
  belongs_to :country_origin, class_name: "Country"
  belongs_to :order
  belongs_to :order_line
  belongs_to :product
  belongs_to :variant

  before_validation :default_line_number

  def calculate_total_discounts
    [:air_sea_discount, :early_pay_discount, :trade_discount].map {|m| self.public_send(m) }.compact.sum
  end

  def calculate_total_charges
    [:middleman_charge].map {|m| self.public_send(m) }.compact.sum
  end

  private
  
  def parent_obj #supporting method for DefaultLineNumberSupport
    self.invoice
  end
end
