# == Schema Information
#
# Table name: booking_lines
#
#  id             :integer          not null, primary key
#  product_id     :integer
#  shipment_id    :integer
#  line_number    :integer
#  quantity       :decimal(13, 4)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  gross_kgs      :decimal(9, 2)
#  cbms           :decimal(9, 5)
#  carton_qty     :integer
#  carton_set_id  :integer
#  order_id       :integer
#  order_line_id  :integer
#  container_size :string(255)
#  variant_id     :integer
#
# Indexes
#
#  index_booking_lines_on_order_id_and_order_line_id  (order_id,order_line_id)
#  index_booking_lines_on_order_line_id               (order_line_id)
#  index_booking_lines_on_product_id                  (product_id)
#  index_booking_lines_on_shipment_id                 (shipment_id)
#  index_booking_lines_on_variant_id                  (variant_id)
#

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

  def product_summed_order_quantity
    if self.order
      self.order.order_lines.select { |ol| self.product_id == ol.product_id }.inject(0) {|acc, nxt| acc + nxt.quantity }
    end
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
