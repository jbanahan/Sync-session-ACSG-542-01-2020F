class BookingLine < ActiveRecord::Base
  belongs_to :order
  belongs_to :order_line
  belongs_to :product

end
