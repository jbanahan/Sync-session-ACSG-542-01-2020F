class BookingLine < ActiveRecord::Base
  belongs_to :shipment
  belongs_to :carton_set
  belongs_to :product
  belongs_to :order
  belongs_to :order_line

  validates_uniqueness_of :line_number, :scope => :shipment_id

  after_save :order_line_takes_priority

  def customer_order_number
    this_order = self.order || self.order_line.try(:order)
    this_order.try(:customer_order_number)
  end

  def customer_order_and_line_number
    if self.order_line_id
      "#{customer_order_number} - #{self.order_line.line_number}"
    else
      customer_order_number
    end
  end

  private
  def parent_obj #supporting method for LinesSupport
    self.shipment
  end

  def parent_id_where #supporting method for LinesSupport
    return :shipment_id => self.shipment.id
  end

  def order_line_takes_priority
    if order_line_id && (product_id || order_id)
      self.update_attributes product_id: nil, order_id: nil
    end
  end

end
