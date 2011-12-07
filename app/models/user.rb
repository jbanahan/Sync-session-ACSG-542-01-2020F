class User < ActiveRecord::Base
  cattr_accessor :current

  acts_as_authentic
  
  attr_accessible :username, :email, :password, 
    :password_confirmation, :time_zone, 
    :email_format, :company_id,
    :first_name, :last_name, :search_open,
    :order_view, :order_edit, :order_delete, :order_attach, :order_comment,
    :shipment_view, :shipment_edit, :shipment_delete, :shipment_attach, :shipment_comment,
    :sales_order_view, :sales_order_edit, :sales_order_delete, :sales_order_attach, :sales_order_comment,
    :delivery_view, :delivery_edit, :delivery_delete, :delivery_attach, :delivery_comment,
    :product_view, :product_edit, :product_delete, :product_attach, :product_comment,
    :entry_view,
    :broker_invoice_view,
    :classification_view, :classification_edit
  
  belongs_to :company
  belongs_to :run_as, :class_name => "User"
  
  has_many   :histories, :dependent => :destroy
  has_many   :item_change_subscriptions, :dependent => :destroy
  has_many   :search_setups, :dependent => :destroy
  has_many   :messages, :dependent => :destroy
  has_many   :debug_records, :dependent => :destroy
  has_many   :dashboard_widgets, :dependent => :destroy
  has_many   :imported_files
  has_many   :instant_classification_results, :foreign_key => :run_by_id
  has_many   :report_results, :foreign_key => :run_by_id
  
  validates  :company, :presence => true
  
  def self.find_not_locked(login) 
    u = User.where(:username => login).first
    unless u.nil? || u.company.locked
      return u
    else
      return nil
    end
  end

  def debug_active?
    !self.debug_expires.blank? && self.debug_expires>Time.now
  end
  #send password reset email to user
  def deliver_password_reset_instructions!
    reset_perishable_token!
    OpenMailer.send_password_reset(self).deliver
  end
  
  # is an administrator within the application (as opposed to a sys_admin who is an Aspect 9 employee with master control)
  # If you are a sys_admin, you are automatically an admin (as long as this method is called instead of looking directly at the db value)
  def admin?
    self.admin || self.sys_admin
  end

  # is a super administrator (generally an Aspect 9 employee) who can control settings not visible to other users
  def sys_admin?
    self.sys_admin
  end
  
  def active?
    return !self.disabled
  end
  
  #should the advanced search box be open on the user's screen
  def search_open?
    return self.search_open
  end

  def full_name
    n = (self.first_name.nil? ? '' : self.first_name + " ") + (self.last_name.nil? ? '' : self.last_name)
    n = self.username if n.strip.length==0
    return n
  end
  
  def zendesk_url
    timestamp = Time.now.utc.to_i.to_s
    token = "MrpSvPXafsfZKuQzYAvpCTjbhe5WDVvPwmfzAneyTcTvVsHc"
    base_url = "http://support.chain.io/access/remote"
    hash_base = self.full_name << self.email << token << timestamp
    hash = Digest::MD5.hexdigest(hash_base)
    "#{base_url}?#{{:email=>self.email,:name=>self.full_name,:timestamp=>timestamp,:hash=>hash}.to_query}"
  end

  def can_view?(user)
    return user.admin? || self==user
  end
  
  def can_edit?(user)
    return user.admin? || self==user
  end

  # Can the given user view items for the given module
  def view_module? core_module
    case core_module
    when CoreModule::ORDER
      return self.view_orders?
    when CoreModule::SHIPMENT
      return self.view_shipments?
    when CoreModule::PRODUCT
      return self.view_products?
    when CoreModule::SALE
      return self.view_sales_orders?
    when CoreModule::DELIVERY
      return self.view_deliveries?
    when CoreModule::ORDER_LINE
      return self.view_orders?
    when CoreModule::SHIPMENT_LINE
      return self.view_shipments?
    when CoreModule::DELIVERY_LINE
      return self.view_deliveries?
    when CoreModule::SALE_LINE
      return self.view_sales_orders?
    when CoreModule::TARIFF
      return self.view_products?
    when CoreModule::CLASSIFICATION
      return self.view_products?
    when CoreModule::OFFICIAL_TARIFF
      return true
    when CoreModule::ENTRY
      return self.view_entries?
    when CoreModule::BROKER_INVOICE
      return self.view_broker_invoices?
    when CoreModule::BROKER_INVOICE_LINE
      return self.view_broker_invoices?
    end
    return false
  end
  
  #permissions
  def view_broker_invoices?
    return self.broker_invoice_view && self.company.view_broker_invoices?
  end
  def view_entries?
    return self.entry_view? && self.company.view_entries?
  end
  def view_orders?
    return self.order_view? && self.company.view_orders? 
  end
  def add_orders?
    return self.order_edit? && self.company.add_orders?
  end
  def edit_orders?
    return self.order_edit? && self.company.edit_orders?
  end
  def delete_orders?
    return self.order_delete? && self.company.delete_orders?
  end
  def attach_orders?
    return self.order_attach? && self.company.attach_orders?
  end
  def comment_orders?
    return self.order_comment? && self.company.comment_orders?
  end
  
  def view_products?
    return self.product_view? && self.company.view_products? 
  end
  def add_products?
    return self.product_edit? && self.company.add_products?
  end
  def edit_products?
    return self.product_edit? && self.company.edit_products?
  end
  def create_products?
    return add_products?
  end
  def delete_products?
    return self.product_delete? && self.company.delete_products?
  end
  def attach_products?
    return self.product_attach? && self.company.attach_products?
  end
  def comment_products?
    return self.product_comment? && self.company.comment_products?
  end
  
  def view_sales_orders?
    return self.sales_order_view? && self.company.view_sales_orders? 
  end
  def add_sales_orders?
    return self.sales_order_edit? && self.company.add_sales_orders?
  end
  def edit_sales_orders?
    return self.sales_order_edit? && self.company.edit_sales_orders?
  end
  def delete_sales_orders?
    return self.sales_order_delete? && self.company.delete_sales_orders?
  end
  def attach_sales_orders?
    return self.sales_order_attach? && self.company.attach_sales_orders?
  end
  def comment_sales_orders?
    return self.sales_order_comment? && self.company.comment_sales_orders?
  end

  
  def view_shipments?
    return self.shipment_view && self.company.view_shipments?
  end
  def add_shipments?
    return self.shipment_edit? && self.company.add_shipments?
  end
  def edit_shipments?
    return self.shipment_edit? && self.company.edit_shipments?
  end
  def delete_shipments?
    return self.shipment_delete? && self.company.delete_shipments?
  end
  def comment_shipments?
    return self.shipment_comment? && self.company.comment_shipments?
  end
  def attach_shipments?
    return self.shipment_attach? && self.company.attach_shipments?
  end
  
  def view_deliveries?
    return self.delivery_view? && self.company.view_deliveries?
  end
  def add_deliveries?
    return self.delivery_edit? && self.company.add_deliveries?
  end
  def edit_deliveries?
    return self.delivery_edit? && self.company.edit_deliveries?
  end
  def delete_deliveries?
    return self.delivery_delete? && self.company.delete_deliveries?
  end
  def comment_deliveries?
    return self.delivery_comment? && self.company.comment_deliveries?
  end
  def attach_deliveries?
    return self.delivery_attach? && self.company.attach_deliveries?
  end

  def add_classifications?
    return self.classification_edit? && self.company.add_classifications?
  end
  def edit_classifications?
    return add_classifications?
  end
  
  def edit_milestone_plans?
    return self.admin?
  end
  
  def edit_status_rules?
    return self.admin?
  end


  def master_company?
    @mc = self.company.master? if @mc.nil?
    @mc
  end

  private
  def master_setup
    MasterSetup.get 
  end

end
