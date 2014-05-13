class Container < ActiveRecord::Base
  belongs_to :entry, inverse_of: :containers
  attr_accessible :container_number, :container_size, :goods_description, :quantity, :size_description, :teus, :uom, :weight
end
