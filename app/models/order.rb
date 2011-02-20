class Order < ActiveRecord::Base
  include OrderSupport
  include CustomFieldSupport
  
  belongs_to :division
	belongs_to :vendor,  :class_name => "Company"
	belongs_to :ship_to, :class_name => "Address"
	
	validates  :vendor, :presence => true
	
	has_many	 :order_lines, :dependent => :destroy, :order => 'line_number'
	has_many   :histories, :dependent => :destroy
	has_many   :item_change_subscriptions
  has_many   :comments, :as => :commentable
  has_many   :attachments, :as => :attachable 	
	
	def related_shipments
	  r = Set.new
	  self.order_lines.each do |line|
	    r = r + line.related_shipments
	  end
	  return r
	end
	
	def can_view?(user)
	  return user.view_orders? && (user.company.master || (user.company.vendor && user.company_id == self.vendor_id))
	end
	
	def can_edit?(user)
	  return user.edit_orders?
	end
	
	def self.find_by_vendor(vendor)
    return Order.where({:vendor_id => vendor})
  end
  
  def find_same
    found = Order.where({:order_number => self.order_number})
    raise "Found multiple orders with the same order number #{self.order_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end
  
  def locked?
    !self.vendor.nil? && self.vendor.locked?
  end
  
  #only merges this object, not related objects (like details). 
  #The other_object overwrites everything except id. 
  def shallow_merge_into(other_order,options={})
    dont_copy = ['id','created_at','updated_at','order_number']
    can_blank = options[:can_blank].nil? ? [] : options[:can_blank]
    updated_attribs = {} 
    self.attributes.each_key do |k|
      unless dont_copy.include?(k)
        if other_order.attribute_present?(k)
          updated_attribs[k] = other_order.attributes[k]
        elsif can_blank.include?(k)
          updated_attribs[k] = nil
        end
      end
    end
    self.attributes= updated_attribs
  end
  
  def shipped_qty
    q = 0
    self.order_lines.each do |line|
      q = q + line.shipped_qty
    end
    return q
  end
  
  def ordered_qty
    #optimize with a single query
    q = 0
    self.order_lines.each do |line|
      q = q + line.ordered_qty
    end
    return q
  end
  
  #gets a list of unique products on the order
  def unique_products
    p_hash = {}
    self.order_lines.each do |line|
      prod = line.product
      if p_hash[prod.id].nil?
        prod.instance_variable_set(:@ordered_qty, line.ordered_qty)
        prod.instance_variable_set(:@shipped_qty, line.shipped_qty)
        p_hash[prod.id] = prod
      else
        pe = p_hash[prod.id]
        pe.instance_variable_set(:@ordered_qty, pe.instance_variable_get(:@ordered_qty)+line.ordered_qty)
        pe.instance_variable_set(:@shipped_qty, pe.instance_variable_get(:@shipped_qty)+line.shipped_qty)
      end
    end
    return p_hash.values
  end
  
  private
  #needed for OrderSupport mixin
  def get_lines
    return self.order_lines
  end
end
