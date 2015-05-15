class BookingLine < ActiveRecord::Base
  belongs_to :shipment
  belongs_to :order
  belongs_to :order_line
  belongs_to :product

end
