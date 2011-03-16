class OrderLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  
  belongs_to :product
  belongs_to :order
	
	has_many	:piece_sets, :dependent => :destroy
  has_many   :histories, :dependent => :destroy
	
  before_validation :set_line_number 
  before_validation :set_ordered_quantity

	validates :product, :presence => true
	validates_uniqueness_of :line_number, :scope => :order_id
	
  def locked? 
    (!parent_obj.nil? && parent_obj.locked?) ||
    (!self.product.nil? && self.product.locked?)
  end


	def related_shipments
	  rVal = Set.new
	  self.piece_sets.each do |p|
	    rVal << p.shipment
	  end
	  return rVal
	end
	
	def shipped_qty
	  self.piece_sets.where("piece_sets.shipment_id is not null").sum("quantity")
	end
	
	def received_qty
	  self.piece_sets.where("inventory_in_id is not null").sum("quantity")
	end
	
	def find_same
    found = OrderLine.where({:order_id => self.order_id, :line_number => self.line_number})
    raise "Found multiple order lines with the same order id #{self.order_id} & line number #{self.line_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end
  
  def shallow_merge_into(other_line,options={})
    dont_copy = ['id','created_at','updated_at','line_number']
    can_blank = options[:can_blank].nil? ? [] : options[:can_blank]
    updated_attribs = {} 
    self.attributes.each_key do |k|
      unless dont_copy.include?(k)
        if other_line.attribute_present?(k)
          updated_attribs[k] = other_line.attributes[k]
        elsif can_blank.include?(k)
          updated_attribs[k] = nil
        end
      end
    end
    self.attributes= updated_attribs
  end

  private
  def parent_obj #supporting method for LinesSupport
    self.order
  end
  
  def parent_id_where #supporting method for LinesSupport
    return :order_id => self.order.id
  end
	
end
