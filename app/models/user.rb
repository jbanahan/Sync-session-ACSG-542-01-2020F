class User < ActiveRecord::Base
  cattr_accessor :current

  acts_as_authentic
  
  attr_accessible :username, :email, :password, 
    :password_confirmation, :time_zone, 
    :email_format, :company_id,
    :first_name, :last_name, :search_open
  
  belongs_to :company
  
  has_many   :histories, :dependent => :destroy
  has_many   :item_change_subscriptions, :dependent => :destroy
  has_many   :search_setups, :dependent => :destroy
  has_many   :messages, :dependent => :destroy
  has_many   :debug_records, :dependent => :destroy
  has_many   :dashboard_widgets, :dependent => :destroy
  has_many   :imported_files
  
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
  
  #permissions
  def view_orders?
    return self.order_view? && master_setup.order_enabled && (master_company? || self.company.vendor?)
  end
  def add_orders?
    return self.order_edit? && master_setup.order_enabled && (master_company?)
  end
  def edit_orders?
    return self.order_edit? && master_setup.order_enabled && (master_company?)
  end
  def delete_orders?
    return self.order_delete? && master_setup.order_enabled && master_company?
  end
  def attach_orders?
    return self.order_attach? && master_setup.order_enabled && (master_company? || self.company.vendor?)
  end
  def comment_orders?
    return self.order_comment? && master_setup.order_enabled && (master_company? || self.company.vendor?)
  end
  
  def view_products?
    return self.product_view? && (master_company? || self.company.vendor? || self.company.carrier?)
  end
  def add_products?
    return self.product_edit? && master_company? 
  end
  def edit_products?
    return self.product_edit? && master_company?
  end
  def create_products?
    return add_products?
  end
  def delete_products?
    return self.product_delete? && master_company?
  end
  def attach_products?
    return self.product_attach? && (master_company? || self.company.vendor? || self.company.carrier?)
  end
  def comment_products?
    return self.product_comment? && (master_company? || self.company.vendor? || self.company.carrier?)
  end
  
  def view_sales_orders?
    return self.sales_order_view? && master_setup.sales_order_enabled && (master_company? || self.company.customer?)
  end
  def add_sales_orders?
    return self.sales_order_edit? && master_setup.sales_order_enabled && (master_company?)
  end
  def edit_sales_orders?
    return self.sales_order_edit? && master_setup.sales_order_enabled && (master_company?)
  end
  def delete_sales_orders?
    return self.sales_order_delete? && master_setup.sales_order_enabled && master_company?
  end
  def attach_sales_orders?
    return self.sales_order_attach? && master_setup.sales_order_enabled && (master_company? || self.company.customer?)
  end
  def comment_sales_orders?
    return self.sales_order_comment? && master_setup.sales_order_enabled && (master_company? || self.company.customer?)
  end

  
  def view_shipments?
    return self.shipment_view && company_view_edit_shipments? 
  end
  def add_shipments?
    return self.shipment_edit? && company_view_edit_shipments?
  end
  def edit_shipments?
    return self.shipment_edit? && company_view_edit_shipments?
  end
  def delete_shipments?
    return self.shipment_delete? && master_setup.shipment_enabled? && master_company?
  end
  def comment_shipments?
    return self.shipment_comment? && company_view_edit_shipments?
  end
  def attach_shipments?
    return self.shipment_attach? && company_view_edit_shipments?
  end
  
  def view_deliveries?
    return self.delivery_view? && company_view_deliveries?
  end
  def add_deliveries?
    return self.delivery_edit? && company_edit_deliveries? 
  end
  def edit_deliveries?
    return self.delivery_edit? && company_edit_deliveries?
  end
  def delete_deliveries?
    return self.delivery_delete? && master_setup.delivery_enabled && master_company?
  end
  def comment_deliveries?
    return self.delivery_comment? && company_view_deliveries? 
  end
  def attach_deliveries?
    return self.delivery_attach? && company_view_deliveries?
  end

  def view_classifications?
    return self.classification_view? && master_setup.classification_enabled && (master_company? || self.company.vendor? || self.company.carrier?)
  end
  def add_classifications?
    return self.classification_edit? && master_setup.classification_enabled && master_company?
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

  def company_view_deliveries?
    company_edit_deliveries? || (self.company.customer? && master_setup.delivery_enabled)
  end
  def company_edit_deliveries?
    master_setup.delivery_enabled && (self.company.master || self.company.carrier?)
  end
  def company_view_edit_shipments?
    master_setup.shipment_enabled && (master_company? || self.company.vendor? || self.company.carrier?)
  end
end
