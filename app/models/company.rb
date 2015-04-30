class Company < ActiveRecord::Base
  include CoreObjectSupport
	validates	:name,	:presence => true
	validate  :master_lock
  validates_uniqueness_of :system_code, :if => lambda { !self.system_code.blank? }
  validates_uniqueness_of :alliance_customer_number, :if => lambda {!self.alliance_customer_number.blank?}, :message=>"is already taken."

	has_many	:addresses, :dependent => :destroy
	has_many	:divisions, :dependent => :destroy
  has_many  :importer_products, :class_name => 'Product', :foreign_key=>'importer_id'
  has_many  :importer_orders, :class_name => 'Order', :foreign_key => 'importer_id', :dependent => :destroy
  has_many  :factory_orders, :class_name => 'Order', :foreign_key => 'factory_id'
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
  has_many  :attachment_archives
  has_many  :attachment_archive_manifests, :dependent=>:destroy
  has_many  :surveys, dependent: :destroy
  has_many  :attachments, as: :attachable, dependent: :destroy
  has_many  :plants, dependent: :destroy, inverse_of: :company

  has_one :attachment_archive_setup, :dependent => :destroy

  has_and_belongs_to_many :linked_companies, :class_name=>"Company", :join_table=>"linked_companies", :foreign_key=>'parent_id', :association_foreign_key=>'child_id'

  scope :carriers, where(:carrier=>true)
  scope :vendors, where(:vendor=>true)
  scope :customers, where(:customer=>true)
  scope :importers, where(:importer=>true)
  scope :consignees, where(:consignee=>true)
  scope :agents, where(:agent=>true)
  scope :by_name, order("companies.name ASC")
  scope :active_importers, where("companies.id in (select importer_id from products where products.created_at > '2011') or companies.id in (select importer_id from entries where entries.file_logged_date > '2011')")
  #find all companies that have attachment_archive_setups that include a start date
  scope :attachment_archive_enabled, joins("LEFT OUTER JOIN attachment_archive_setups on companies.id = attachment_archive_setups.company_id").where("attachment_archive_setups.start_date is not null")

  def linked_company? c
    self.linked_companies.include? c
  end
	def self.find_can_view(user)
	  if user.company.master
	    return Company.where("1=1")
	  else
	    return Company.where(:id => user.company_id)
	  end
	end

  def plants_user_can_view user
    self.plants.reject{|plant| !plant.can_view?(user)}
  end

  def self.search_secure user, base_search
    base_search.where(secure_search(user))
  end

  def self.secure_search user
    if user.company.master?
      '1=1'
    else
      "companies.id = #{user.company_id} OR (companies.id IN (SELECT linked_companies.child_id FROM linked_companies WHERE linked_companies.parent_id = #{user.company_id}))"  
    end
  end

  def self.search_where user
    # Since we only do full searches on Vendors, scope it only to vendor companies.
    "companies.vendor = 1 AND " + secure_search(user)
  end

  # find all companies that aren't children of this one through the linked_companies relationship
  def unlinked_companies
    Company.select("distinct companies.*").joins("LEFT OUTER JOIN (select child_id as cid FROM linked_companies where parent_id = #{self.id}) as lk on companies.id = lk.cid").where("lk.cid IS NULL").where("NOT companies.id = ?",self.id)
  end

	def can_edit?(user)
	  return true if user.admin?
    return true if self.vendor? && user.edit_vendors?
    return false
	end

	def can_view?(user)
	  if user.company.master
	    return true
	  else
	    return user.company == self
	  end
	end

  def can_view_as_vendor?(user)
    self.vendor &&
    user.view_vendors? && (
      user.company.master? || user.company == self || user.company.linked_company?(self)
    )
  end

  def can_attach?(user)
    return true if user.admin?
    return true if self.can_view_as_vendor?(user) && user.attach_vendors?
    return false
  end

  def can_comment?(user)
    return true if user.admin?
    return true if self.can_view_as_vendor?(user) && user.comment_vendors?
    return false
  end

  #migrate all users and surveys to the target company
  def migrate_accounts target_company
    self.users.update_all(company_id:target_company.id,updated_at:Time.now)
    self.surveys.update_all(company_id:target_company.id,updated_at:Time.now)
  end

	def self.not_locked
	  Company.where("locked = ? OR locked is null",false)
	end

	def self.find_master
	  Company.first_or_create(:master => true,name:'Master Company')
	end

  def visible_companies
    if self.master?
      Company.scoped
    else
      Company.where("companies.id = ? OR companies.master = ? OR companies.id IN (select child_id from linked_companies where parent_id = ?)",self.id,true,self.id)
    end
  end

  def visible_companies_with_users
    visible_companies.where('companies.id IN (SELECT company_id FROM users)')
  end


  #permissions
  def view_security_filings?
    master_setup.security_filing_enabled? && (self.master? || self.broker? || self.importer?)
  end
  def edit_security_filings?
    master_setup.security_filing_enabled? && (self.master? || self.broker?)
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
    return master_setup.order_enabled && (self.master? || self.vendor? || self.importer? || self.agent?)
  end
  def add_orders?
    return master_setup.order_enabled && (self.master?)
  end
  def edit_orders?
    return master_setup.order_enabled && (self.master? || self.importer?)
  end
  def delete_orders?
    return master_setup.order_enabled && self.master?
  end
  def attach_orders?
    return master_setup.order_enabled && (self.master? || self.vendor? || self.importer? || self.agent?)
  end
  def comment_orders?
    return master_setup.order_enabled && (self.master? || self.vendor? || self.importer? || self.agent?)
  end

  def view_vendors?
    return master_setup.vendor_management_enabled?
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

  def view_projects?
    self.master? && master_setup.project_enabled?
  end
  def edit_projects?
    self.master? && master_setup.project_enabled?
  end

  def name_with_customer_number
    n = self.name
    n += " (#{self.fenix_customer_number})" unless self.fenix_customer_number.blank?
    n += " (#{self.alliance_customer_number})" unless self.alliance_customer_number.blank?
    n
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
    master_setup.shipment_enabled && (self.master? || self.vendor? || self.carrier? || self.agent? || self.importer?)
  end
end
