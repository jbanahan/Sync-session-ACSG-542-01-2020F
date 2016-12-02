class BookingLine < ActiveRecord::Base
  belongs_to :shipment
  belongs_to :carton_set
  belongs_to :product
  belongs_to :order
  belongs_to :order_line
  belongs_to :variant

  validates_uniqueness_of :line_number, :scope => :shipment_id

  before_validation :set_product_and_order

  def customer_order_number
    this_order = self.order || self.order_line.try(:order)
    order_number = nil
    if this_order
      order_number = this_order.customer_order_number
      order_number = this_order.order_number if order_number.blank?
    end
    order_number
  end

  def customer_order_and_line_number
    if self.order_line_id
      "#{customer_order_number} - #{self.order_line.line_number}"
    else
      customer_order_number
    end
  end

  def product_identifier
    this_product = self.product || self.order_line.try(:product)
    this_product.try(:unique_identifier)
  end

  private
  def parent_obj #supporting method for LinesSupport
    self.shipment
  end

  def parent_id_where #supporting method for LinesSupport
    return :shipment_id => self.shipment.id
  end

  def set_product_and_order
    if self.order_line
      self.product = self.order_line.product
      self.order = self.order_line.order
    end
  end

end
