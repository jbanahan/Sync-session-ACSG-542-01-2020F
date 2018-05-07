# == Schema Information
#
# Table name: containers
#
#  container_number      :string(255)
#  container_pickup_date :date
#  container_return_date :date
#  container_size        :string(255)
#  created_at            :datetime         not null
#  entry_id              :integer
#  fcl_lcl               :string(255)
#  goods_description     :string(255)
#  id                    :integer          not null, primary key
#  port_of_loading_id    :integer
#  port_of_delivery_id   :integer
#  quantity              :integer
#  seal_number           :string(255)
#  shipment_id           :integer
#  size_description      :string(255)
#  teus                  :integer
#  uom                   :string(255)
#  updated_at            :datetime         not null
#  weight                :integer
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
  attr_accessible :container_number, :container_size, :goods_description, :quantity, :size_description, :teus, :uom, :weight, :seal_number, :container_pickup_date, :container_return_date, :port_of_loading_id, :port_of_delivery_id

  belongs_to :port_of_loading, :class_name=>"Port"
  belongs_to :port_of_delivery, :class_name=>"Port"


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
