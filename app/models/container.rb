# == Schema Information
#
# Table name: containers
#
#  id                    :integer          not null, primary key
#  container_number      :string(255)
#  container_size        :string(255)
#  size_description      :string(255)
#  weight                :integer
#  quantity              :integer
#  uom                   :string(255)
#  goods_description     :string(255)
#  seal_number           :string(255)
#  teus                  :integer
#  fcl_lcl               :string(255)
#  entry_id              :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  shipment_id           :integer
#  container_pickup_date :date
#  container_return_date :date
#  port_of_loading_id    :integer
#  port_of_delivery_id   :integer
#
# Indexes
#
#  index_containers_on_entry_id     (entry_id)
#  index_containers_on_shipment_id  (shipment_id)
#

class Container < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :entry, inverse_of: :containers
  belongs_to :shipment, inverse_of: :containers, touch: true
  has_many :shipment_lines, dependent: :destroy, inverse_of: :container
  has_many :commercial_invoice_lines, inverse_of: :container
  attr_accessible :container_number, :container_size, :goods_description, :quantity, :size_description, :teus, :uom, :weight, :seal_number


  def self.parse_container_size_description description
    case description
    when /Standard Dry 40 (ft\.?|foot)/i
      "40DV"
    when /High Cube 40 (ft\.?|foot)/i
      "40HQ"
    when /Standard Dry 20 (ft\.?|foot)/i
      "20DV"
    when /High Cube 45 (ft\.?|foot)/i
      "45HQ"
    else
      nil
    end
  end
end
