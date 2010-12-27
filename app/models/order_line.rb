class OrderLine < ActiveRecord::Base
  include LinesSupport
  
  belongs_to :product
  belongs_to :order
	
	has_many	:piece_sets, :dependent => :destroy
  has_many   :histories, :dependent => :destroy
	
	validates :product, :presence => true
	validates_uniqueness_of :line_number, :scope => :order_id
	
  def locked? 
    (!parent_obj.nil? && parent_obj.locked?) ||
    (!self.product.nil? && self.product.locked?)
  end

	
	def make_unpacked_piece_set
	  set_qty = self.ordered_qty - self.piece_sets.sum("quantity") 
    ps = self.piece_sets.build
    ps.product_id = self.product_id
	  ps.quantity = set_qty < 0 ? 0 : set_qty
	  return ps
	end
	
	def related_shipments
	  rVal = Set.new
	  self.piece_sets.each do |p|
	    rVal << p.shipment
	  end
	  return rVal
	end
	
	def shipped_qty
	  self.piece_sets.sum("quantity")
	end
	
	def received_qty
	  self.piece_sets.where("inventory_in_id is not null").sum("quantity")
	end
	
	def find_same
    found = OrderLine.where({:order_id => self.order_id, :line_number => self.line_number})
    raise "Found multiple order lines with the same order id #{self.order_id} & line number #{self.line_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end

  private
  def parent_obj #supporting method for LinesSupport
    self.order
  end
  
  def parent_id_where #supporting method for LinesSupport
    return :order_id => self.order.id
  end
	
end
