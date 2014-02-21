class OrderLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  include ShallowMerger
  
  belongs_to :order
  belongs_to :product
  validates :product, :presence => true, :unless => :has_item_identifier?

  has_many   :histories, :dependent => :destroy
  has_many  :shipment_lines, :through => :piece_sets
	
  validates_uniqueness_of :line_number, :scope => :order_id	


	def related_shipments
	  rVal = Set.new
	  self.piece_sets.each do |p|
	    rVal << p.shipment_line.shipment unless p.shipment_line.nil?
	  end
	  return rVal
	end
	
	def shipped_qty
    q = 0
	  self.piece_sets.each {|p| q += p.quantity unless p.shipment_line_id.nil?}
    q
	end
	
	def received_qty
	  0
  end

	
	def find_same
    found = OrderLine.where({:order_id => self.order_id, :line_number => self.line_number})
    raise "Found multiple order lines with the same order id #{self.order_id} & line number #{self.line_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end
  
  dont_shallow_merge :OrderLine, ['id','created_at','updated_at','line_number']

  private
  def parent_obj #supporting method for LinesSupport
    self.order
  end
  
  def parent_id_where #supporting method for LinesSupport
    return :order_id => self.order.id
  end

  def has_item_identifier?
    !(self.item_identifier.blank?)
  end

end
