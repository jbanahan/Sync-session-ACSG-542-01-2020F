# == Schema Information
#
# Table name: commercial_invoice_lacey_components
#
#  id                           :integer          not null, primary key
#  line_number                  :integer
#  detailed_description         :string(255)
#  value                        :decimal(9, 2)
#  name                         :string(255)
#  quantity                     :decimal(12, 3)
#  unit_of_measure              :string(255)
#  genus                        :string(255)
#  species                      :string(255)
#  harvested_from_country       :string(255)
#  percent_recycled_material    :decimal(5, 2)
#  container_numbers            :string(255)
#  commercial_invoice_tariff_id :integer          not null
#
# Indexes
#
#  lacey_components_by_tariff_id  (commercial_invoice_tariff_id)
#

class CommercialInvoiceLaceyComponent < ActiveRecord::Base
  belongs_to :commercial_invoice_tariff, inverse_of: :commercial_invoice_lacey_components
end
