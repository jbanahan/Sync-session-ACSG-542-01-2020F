class Company < ActiveRecord::Base
	validates	:name,	:presence => true
	validate  :master_lock
  validates_uniqueness_of :system_code, :if => lambda { !self.system_code.blank? }
  validates_uniqueness_of :alliance_customer_number, :if => lambda {!self.alliance_customer_number.blank?}, :message=>"is already taken."

	has_many	:addresses, :dependent => :destroy
	has_many	:divisions, :dependent => :destroy
	has_many	:vendor_orders, :class_name => "Order", :foreign_key => "vendor_id", :dependent => :destroy
	has_many	:vendor_products, :class_name => "Product", :foreign_key => "vendor_id", :dependent => :destroy
	has_many  :vendor_shipments, :class_name => "Shipment", :foreign_key => "vendor_id", :dependent => :destroy
	has_many  :carrier_shipments, :class_name => "Shipment", :foreign_key => "carrier_id", :dependent => :destroy
	has_many  :carrier_deliveries, :class_name => "Delivery", :foreign_key => "carrier_id", :dependent => :destroy
	has_many  :customer_sales_orders, :class_name => "SalesOrder", :foreign_key => "customer_id", :dependent => :destroy
	has_many  :customer_deliveries, :class_name => "Delivery", :foreign_key => "customer_id", :dependent => :destroy
	has_many  :users, :dependent => :destroy, :order=>"first_name ASC, last_name ASC, username ASC"
	has_many	:orders, :through => :divisions, :dependent => :destroy
	has_many	:products, :through => :divisions, :dependent => :destroy
	has_many  :histories, :dependent => :destroy
  has_many  :power_of_attorneys, :dependent => :destroy
  has_many  :drawback_claims
  has_many  :charge_categories, :dependent => :destroy

  has_and_belongs_to_many :linked_companies, :class_name=>"Company", :join_table=>"linked_companies", :foreign_key=>'parent_id', :association_foreign_key=>'child_id'
	
  scope :carriers, where(:carrier=>true)
  scope :vendors, where(:vendor=>true)
  scope :customers, where(:customer=>true)
  scope :importers, where(:importer=>true)
  scope :by_name, order("companies.name ASC")

	
	def self.find_can_view(user)
	  if user.company.master
	    return Company.where("1=1")
	  else
	    return Company.where(:id => user.company_id)
	  end
	end
	
  # find all companies that aren't children of this one through the linked_companies relationship
  def unlinked_companies
    Company.select("distinct companies.*").joins("LEFT OUTER JOIN (select child_id as cid FROM linked_companies where parent_id = #{self.id}) as lk on companies.id = lk.cid").where("lk.cid IS NULL").where("NOT companies.id = ?",self.id)
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
  def view_security_filings?
    master_setup.security_filing_enabled? && (self.master? || self.broker? || self.importer?) 
  end
  def edit_security_filings?
    false
  end
  def comment_security_filings?
    view_security_filings?
  end
  def attach_security_filings?
    view_security_filings?
  end
  def view_drawback?
    master_setup.drawback_enabled?
  end
  def edit_drawback?
    master_setup.drawback_enabled?
  end
  def view_surveys?
    true
  end
  def edit_surveys?
    true
  end
  def view_commercial_invoices?
    master_setup.entry_enabled
  end
  def edit_commercial_invoices?
    master_setup.entry_enabled
  end
  def view_broker_invoices?
    return master_setup.broker_invoice_enabled && (self.master? || self.importer?)
  end
  def edit_broker_invoices?
    master_setup.broker_invoice_enabled && self.master?
  end
  def view_entries?
    master_setup.entry_enabled && (self.master? || self.importer?)
  end
  def comment_entries?
    self.view_entries?
  end
  def attach_entries?
    self.view_entries?
  end
  def edit_entries?
    master_setup.entry_enabled && self.master?
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
    true
  end
  def add_products?
    return self.master? || self.importer? 
  end
  def edit_products?
    return self.master? || self.importer?
  end
  def create_products?
    return add_products?
  end
  def delete_products?
    return self.master?
  end
  def attach_products?
    view_products?
  end
  def comment_products?
    view_products?
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
    return master_setup.classification_enabled && edit_products? 
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
