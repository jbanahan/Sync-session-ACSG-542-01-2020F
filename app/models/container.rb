class Container < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :entry, inverse_of: :containers
  belongs_to :shipment, inverse_of: :containers, touch: true
  has_many :shipment_lines, dependent: :destroy, inverse_of: :container
  attr_accessible :container_number, :container_size, :goods_description, :quantity, :size_description, :teus, :uom, :weight, :seal_number
end
