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
    :entry_view, :entry_comment, :entry_attach, :entry_edit, :drawback_edit, :drawback_view,
    :survey_view, :survey_edit,
    :broker_invoice_view, :broker_invoice_edit,
    :classification_view, :classification_edit,
    :commercial_invoice_view, :commercial_invoice_edit,
    :security_filing_view, :security_filing_edit, :security_filing_comment, :security_filing_attach,
    :support_agent,
    :password_reset,
    :simple_entry_mode
  
  belongs_to :company
  belongs_to :run_as, :class_name => "User"
  
  has_many   :histories, :dependent => :destroy
  has_many   :item_change_subscriptions, :dependent => :destroy
  has_many   :search_setups, :dependent => :destroy
  has_many   :custom_reports, :dependent=> :destroy
  has_many   :messages, :dependent => :destroy
  has_many   :debug_records, :dependent => :destroy
  has_many   :dashboard_widgets, :dependent => :destroy
  has_many   :imported_files
  has_many   :imported_file_downloads
  has_many   :instant_classification_results, :foreign_key => :run_by_id
  has_many   :report_results, :foreign_key => :run_by_id
  has_many   :survey_responses
  has_many   :support_tickets, :foreign_key => :requestor_id
  has_many   :support_tickets_assigned, :foreign_key => :agent_id
  
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
    when CoreModule::COMMERCIAL_INVOICE
      return self.view_commercial_invoices?
    when CoreModule::COMMERCIAL_INVOICE_LINE
      return self.view_commercial_invoices?
    when CoreModule::COMMERCIAL_INVOICE_TARIFF
      return self.view_commercial_invoices?
    when CoreModule::SECURITY_FILING
      return self.view_security_filing?
    end
    return false
  end
  
  #permissions
  def view_security_filings?
    self.security_filing_view? && self.company.view_security_filings? 
  end
  def edit_security_filings?
    self.security_filing_edit? && self.company.edit_security_filings? 
  end
  def attach_security_filings?
    self.security_filing_attach? && self.company.attach_security_filings? 
  end
  def comment_security_filings?
    self.security_filing_comment? && self.company.comment_security_filings? 
  end
  def view_drawback?
    self.drawback_view? && MasterSetup.get.drawback_enabled?
  end
  def edit_drawback?
    self.drawback_edit? && MasterSetup.get.drawback_enabled?
  end
  def view_commercial_invoices?
    self.commercial_invoice_view? && MasterSetup.get.entry_enabled?
  end
  def edit_commercial_invoices?
    self.commercial_invoice_edit? && MasterSetup.get.entry_enabled?
  end
  def view_surveys?
    self.survey_view?
  end
  def edit_surveys?
    self.survey_edit?
  end
  def view_broker_invoices?
    self.broker_invoice_view && self.company.view_broker_invoices?
  end
  def edit_broker_invoices?
    self.broker_invoice_edit && self.company.edit_broker_invoices?
  end
  def view_entries?
    self.entry_view? && self.company.view_entries?
  end
  def comment_entries?
    self.entry_comment? && self.company.view_entries?
  end
  def attach_entries?
    self.entry_attach? && self.company.view_entries?
  end
  def edit_entries?
    self.entry_edit? && self.company.broker?
  end
  def view_orders?
    self.order_view? && self.company.view_orders? 
  end
  def add_orders?
    self.order_edit? && self.company.add_orders?
  end
  def edit_orders?
    self.order_edit? && self.company.edit_orders?
  end
  def delete_orders?
    self.order_delete? && self.company.delete_orders?
  end
  def attach_orders?
    self.order_attach? && self.company.attach_orders?
  end
  def comment_orders?
    self.order_comment? && self.company.comment_orders?
  end
  
  def view_products?
    self.product_view? && self.company.view_products? 
  end
  def add_products?
    self.product_edit? && self.company.add_products?
  end
  def edit_products?
    self.product_edit? && self.company.edit_products?
  end
  def create_products?
    add_products?
  end
  def delete_products?
    self.product_delete? && self.company.delete_products?
  end
  def attach_products?
    self.product_attach? && self.company.attach_products?
  end
  def comment_products?
    self.product_comment? && self.company.comment_products?
  end
  
  def view_sales_orders?
    self.sales_order_view? && self.company.view_sales_orders? 
  end
  def add_sales_orders?
    self.sales_order_edit? && self.company.add_sales_orders?
  end
  def edit_sales_orders?
    self.sales_order_edit? && self.company.edit_sales_orders?
  end
  def delete_sales_orders?
    self.sales_order_delete? && self.company.delete_sales_orders?
  end
  def attach_sales_orders?
    self.sales_order_attach? && self.company.attach_sales_orders?
  end
  def comment_sales_orders?
    self.sales_order_comment? && self.company.comment_sales_orders?
  end

  
  def view_shipments?
    self.shipment_view && self.company.view_shipments?
  end
  def add_shipments?
    self.shipment_edit? && self.company.add_shipments?
  end
  def edit_shipments?
    self.shipment_edit? && self.company.edit_shipments?
  end
  def delete_shipments?
    self.shipment_delete? && self.company.delete_shipments?
  end
  def comment_shipments?
    self.shipment_comment? && self.company.comment_shipments?
  end
  def attach_shipments?
    self.shipment_attach? && self.company.attach_shipments?
  end
  
  def view_deliveries?
    self.delivery_view? && self.company.view_deliveries?
  end
  def add_deliveries?
    self.delivery_edit? && self.company.add_deliveries?
  end
  def edit_deliveries?
    self.delivery_edit? && self.company.edit_deliveries?
  end
  def delete_deliveries?
    self.delivery_delete? && self.company.delete_deliveries?
  end
  def comment_deliveries?
    self.delivery_comment? && self.company.comment_deliveries?
  end
  def attach_deliveries?
    self.delivery_attach? && self.company.attach_deliveries?
  end

  def add_classifications?
    self.classification_edit? && self.company.add_classifications?
  end
  def edit_classifications?
    add_classifications?
  end
  
  def edit_milestone_plans?
    self.admin?
  end
  
  def edit_status_rules?
    self.admin?
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
