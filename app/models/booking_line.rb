class BookingLine < ActiveRecord::Base
  include LinesSupport

  belongs_to :shipment
  belongs_to :carton_set
  belongs_to :product

  validates_uniqueness_of :line_number, :scope => :shipment_id

  def order
    order_line.try(:order)
  end

  def order_line
    order_lines.first
  end

  private
  def parent_obj #supporting method for LinesSupport
    self.shipment
  end

  def parent_id_where #supporting method for LinesSupport
    return :shipment_id => self.shipment.id
  end

end
