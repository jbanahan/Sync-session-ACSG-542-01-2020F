class OrderLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  include ShallowMerger
  include UpdateModelFieldsSupport
  
  belongs_to :order, inverse_of: :order_lines
  belongs_to :ship_to, :class_name => 'Address'

  has_many  :histories, :dependent => :destroy
  has_many  :shipment_lines, :through => :piece_sets
	
  validates_uniqueness_of :line_number, :scope => :order_id	

  TOTAL_COST_SUBQUERY ||= 'IFNULL(IF(order_lines.total_cost_digits IS NULL,(order_lines.price_per_unit * order_lines.quantity),ROUND(order_lines.price_per_unit * order_lines.quantity,total_cost_digits)), 0)'
  def total_cost 
    return 0 if self.price_per_unit.blank? || self.quantity.blank?
    total_cost = self.price_per_unit * self.quantity
    total_cost = BigDecimal(total_cost).round(total_cost_digits) unless self.total_cost_digits.nil?
    total_cost
  end

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

  def unshipped_qty
    self.quantity - shipped_qty
  end
	
	def received_qty
	  self.piece_sets.inject(0) { |i, ps| 
      r = 0
      if ps.shipment_line
        if ps.shipment_line.shipment && ps.shipment_line.shipment.delivered_date
          r = ps.quantity
        end
      end
      i + r
    }
  end

  def shipping?
    self.piece_sets.where("shipment_line_id is not null").count > 0
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

end
