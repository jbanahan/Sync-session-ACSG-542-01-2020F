class Product < ActiveRecord::Base
	
	include CustomFieldSupport
	include StatusableSupport

  CORE_MODULE = CoreModule::PRODUCT


	belongs_to :vendor, :class_name => "Company"
	belongs_to :division
	belongs_to :status_rule
	validates  :vendor, :presence => true
	validates	 :division, :presence => true
	validates	 :unique_identifier, :presence => true
	validates_uniqueness_of :unique_identifier
	
  has_many   :classifications, :dependent => :destroy
	has_many 	 :order_lines, :dependent => :destroy
	has_many   :sales_order_lines, :dependent => :destroy
	has_many	 :piece_sets, :dependent => :destroy
  has_many   :histories, :dependent => :destroy
  has_many   :item_change_subscriptions
  
  accepts_nested_attributes_for :classifications, :allow_destroy => true, 
    :reject_if => lambda { |a| a[:country_id].blank? }
  
	
	def locked?
	  !self.vendor.nil? && self.vendor.locked?
	end
	
	def can_view?(user)
	  return user.company.master || (user.company.vendor && user.company == self.vendor)
	end
	
	def can_edit?(user)
	  return user.edit_products?
	end
  
  
  def current_inventory_qty
    inv_in = inventory_received
    inv_out = PieceSet.where("inventory_out_id is not null AND piece_sets.product_id = ?",self.id).sum("quantity")
    inv_in - inv_out 
  end
  	
	def find_same
	  found = Product.where({:unique_identifier => self.unique_identifier})
    raise "Found multiple orders with the same unique identifier #{self.unique_identifier}" if found.size > 1
    return found.empty? ? nil : found.first
	end
	
  def self.find_can_view(user)
    if user.company.master
      return Product.all
    elsif user.company.vendor
      return Product.where("vendor_id = ?",user.company.id)
    else
      return []
    end
  end
  
  def shallow_merge_into(other_obj,options={})
    dont_copy = ['id','created_at','updated_at','unique_identifier','vendor_id']
    can_blank = options[:can_blank].nil? ? [] : options[:can_blank]
    updated_attribs = {} 
    self.attributes.each_key do |k|
      unless dont_copy.include?(k)
        if other_obj.attribute_present?(k)
          updated_attribs[k] = other_obj.attributes[k]
        elsif can_blank.include?(k)
          updated_attribs[k] = nil
        end
      end
    end
    self.attributes= updated_attribs
  end
  
  def has_orders?
    self.order_lines.length > 0
  end
  def has_shipments?
    PieceSet.where("product_id = ? AND shipment_id is not null", self.id).length > 0
  end
  def has_deliveries?
    PieceSet.where("product_id = ? AND delivery_id is not null", self.id).length > 0
  end
  def has_sales_orders?
    self.sales_order_lines.length > 0
  end
  
  private  
  def inventory_received
    PieceSet.where("inventory_in_id is not null AND piece_sets.product_id = ?",self.id).sum("quantity")
  end
end
