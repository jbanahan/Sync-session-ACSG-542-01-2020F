class Company < ActiveRecord::Base
	validates	:name,	:presence => true
	validate  :master_lock
  validates_uniqueness_of :system_code, :if => lambda { !self.system_code.blank? }
	has_many	:addresses, :dependent => :destroy
	has_many	:divisions, :dependent => :destroy
	has_many	:vendor_orders, :class_name => "Order", :foreign_key => "vendor_id", :dependent => :destroy
	has_many	:vendor_products, :class_name => "Product", :foreign_key => "vendor_id", :dependent => :destroy
	has_many  :vendor_shipments, :class_name => "Shipment", :foreign_key => "vendor_id", :dependent => :destroy
	has_many  :carrier_shipments, :class_name => "Shipment", :foreign_key => "carrier_id", :dependent => :destroy
	has_many  :carrier_deliveries, :class_name => "Delivery", :foreign_key => "carrier_id", :dependent => :destroy
	has_many  :customer_sales_orders, :class_name => "SalesOrder", :foreign_key => "customer_id", :dependent => :destroy
	has_many  :customer_deliveries, :class_name => "Delivery", :foreign_key => "customer_id", :dependent => :destroy
	has_many  :users, :dependent => :destroy
	has_many	:orders, :through => :divisions, :dependent => :destroy
	has_many	:products, :through => :divisions, :dependent => :destroy
	has_many  :histories, :dependent => :destroy
	
	def self.find_carriers
		return Company.where(["carrier = ?",true])
	end
	
	def self.find_vendors
	  return Company.where(["vendor = ?",true])
	end
	
	def self.find_customers
	  return Company.where(["customer = ?",true])
	end
	
	def self.find_can_view(user)
	  if user.company.master
	    return Company.where("1=1")
	  else
	    return Company.where(:id => user.company_id)
	  end
	end
	
	def can_edit?(user)
	  return user.admin?
	end
	
	def can_view?(user)
	  if user.company.master
	    return true
	  else
	    return user.company == self
	  end
	end
	
	def self.not_locked
	  Company.where("locked = ? OR locked is null",false)
	end
	
	def self.find_master
	  Company.where(:master => true).first
	end


  #permissions
  def view_entries?
    return master_setup.entry_enabled && (self.master?)
  end
  def view_orders?
    return master_setup.order_enabled && (self.master? || self.vendor?)
  end
  def add_orders?
    return master_setup.order_enabled && (self.master?)
  end
  def edit_orders?
    return master_setup.order_enabled && (self.master?)
  end
  def delete_orders?
    return master_setup.order_enabled && self.master?
  end
  def attach_orders?
    return master_setup.order_enabled && (self.master? || self.vendor?)
  end
  def comment_orders?
    return master_setup.order_enabled && (self.master? || self.vendor?)
  end
  
  def view_products?
    return (self.master? || self.vendor? || self.carrier?)
  end
  def add_products?
    return self.master? 
  end
  def edit_products?
    return self.master?
  end
  def create_products?
    return add_products?
  end
  def delete_products?
    return self.master?
  end
  def attach_products?
    return (self.master? || self.vendor? || self.carrier?)
  end
  def comment_products?
    return (self.master? || self.vendor? || self.carrier?)
  end
  
  def view_sales_orders?
    return master_setup.sales_order_enabled && (self.master? || self.customer?)
  end
  def add_sales_orders?
    return master_setup.sales_order_enabled && (self.master?)
  end
  def edit_sales_orders?
    return master_setup.sales_order_enabled && (self.master?)
  end
  def delete_sales_orders?
    return master_setup.sales_order_enabled && self.master?
  end
  def attach_sales_orders?
    return master_setup.sales_order_enabled && (self.master? || self.customer?)
  end
  def comment_sales_orders?
    return master_setup.sales_order_enabled && (self.master? || self.customer?)
  end

  
  def view_shipments?
    return company_view_edit_shipments? 
  end
  def add_shipments?
    return company_view_edit_shipments?
  end
  def edit_shipments?
    return company_view_edit_shipments?
  end
  def delete_shipments?
    return master_setup.shipment_enabled? && self.master?
  end
  def comment_shipments?
    return company_view_edit_shipments?
  end
  def attach_shipments?
    return company_view_edit_shipments?
  end
  
  def view_deliveries?
    return company_view_deliveries?
  end
  def add_deliveries?
    return company_edit_deliveries? 
  end
  def edit_deliveries?
    return company_edit_deliveries?
  end
  def delete_deliveries?
    return master_setup.delivery_enabled && self.master?
  end
  def comment_deliveries?
    return company_view_deliveries? 
  end
  def attach_deliveries?
    return company_view_deliveries?
  end

  def add_classifications?
    return master_setup.classification_enabled && self.master?
  end
  def edit_classifications?
    return add_classifications?
  end

	
	private 

  def master_setup
    MasterSetup.get
  end
	def master_lock
	  errors.add(:base, "Master company cannot be locked.") if self.master && self.locked
	end
  def company_view_deliveries?
    company_edit_deliveries? || (self.customer? && master_setup.delivery_enabled)
  end
  def company_edit_deliveries?
    master_setup.delivery_enabled && (self.master? || self.carrier?)
  end
  def company_view_edit_shipments?
    master_setup.shipment_enabled && (self.master? || self.vendor? || self.carrier?)
  end
end
