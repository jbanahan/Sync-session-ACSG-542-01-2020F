class BookingLine < ActiveRecord::Base
  include LinesSupport

  belongs_to :shipment
  belongs_to :carton_set
  belongs_to :product
  belongs_to :order
  belongs_to :order_line

  validates_uniqueness_of :line_number, :scope => :shipment_id

  validates :order_line_takes_priority

  private
  def parent_obj #supporting method for LinesSupport
    self.shipment
  end

  def parent_id_where #supporting method for LinesSupport
    return :shipment_id => self.shipment.id
  end

  def order_line_takes_priority
    if order_line && (product || order)
      self.product = nil
      self.order = nil
    end
  end

end
