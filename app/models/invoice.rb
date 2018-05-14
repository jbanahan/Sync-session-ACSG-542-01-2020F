# == Schema Information
#
# Table name: invoices
#
#  country_origin_id         :integer
#  created_at                :datetime         not null
#  currency                  :string(255)
#  customer_reference_number :string(255)
#  description_of_goods      :text
#  exchange_rate             :decimal(8, 6)
#  factory_id                :integer
#  gross_weight              :decimal(11, 2)
#  gross_weight_uom          :string(255)
#  id                        :integer          not null, primary key
#  importer_id               :integer
#  invoice_date              :date
#  invoice_number            :string(255)
#  invoice_total_domestic    :decimal(13, 2)
#  invoice_total_foreign     :decimal(13, 2)
#  net_invoice_total         :decimal(13, 2)
#  net_weight                :decimal(11, 2)
#  net_weight_uom            :string(255)
#  ship_mode                 :string(255)
#  ship_to_id                :integer
#  terms_of_payment          :string(255)
#  terms_of_sale             :string(255)
#  total_charges             :decimal(11, 2)
#  total_discounts           :decimal(12, 2)
#  updated_at                :datetime         not null
#  vendor_id                 :integer
#  volume                    :decimal(11, 5)
#  volume_uom                :string(255)
#
# Indexes
#
#  index_invoices_on_importer_id     (importer_id)
#  index_invoices_on_invoice_number  (invoice_number)
#

class Invoice < ActiveRecord::Base
  belongs_to :country_origin, :class_name => "Country"
  belongs_to :factory, :class_name => "Company"
  belongs_to :importer, :class_name => "Company"
  belongs_to :ship_to, :class_name => "Address"
  belongs_to :vendor, :class_name => "Company"

  has_many :invoice_lines, :dependent => :destroy, :autosave => true
end
