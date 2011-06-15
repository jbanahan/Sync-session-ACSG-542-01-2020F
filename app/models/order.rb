class Order < ActiveRecord::Base
  include OrderSupport
  include CustomFieldSupport
  include ShallowMerger
  include EntitySnapshotSupport

  belongs_to :division
	belongs_to :vendor,  :class_name => "Company"
	belongs_to :ship_to, :class_name => "Address"
	
	validates  :vendor, :presence => true
	
	has_many	 :order_lines, :dependent => :destroy, :order => 'line_number'
	has_many   :histories, :dependent => :destroy
	has_many   :item_change_subscriptions, :dependent => :destroy
  has_many   :comments, :as => :commentable, :dependent => :destroy
  has_many   :attachments, :as => :attachable, :dependent => :destroy 	
	
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
    found = self.order_number.nil? ? [] : Order.where({:order_number => self.order_number.to_s})
    raise "Found multiple orders with the same order number #{self.order_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end
  
  def locked?
    !self.vendor.nil? && self.vendor.locked?
  end
  
  dont_shallow_merge :Order, ['id','created_at','updated_at','order_number']
  
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
      q = q + line.quantity
    end
    return q
  end
 
  def self.search_secure user, base_object
    if user.company.master
      return base_object.where("1=1")
    elsif user.company.vendor
      return base_object.where(:vendor_id => user.company)
    else
      return base_object.where("1=0")
    end
  end

  private
  #needed for OrderSupport mixin
  def get_lines
    return self.order_lines
  end
end
