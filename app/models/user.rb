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
    return master_setup.order_enabled && (self.company.master? || self.company.vendor?)
  end
  def add_orders?
    return master_setup.order_enabled && (self.company.master?)
  end
  def edit_orders?
    return master_setup.order_enabled && (self.company.master?)
  end
  
  def view_products?
    return self.company.master? || self.company.vendor?
  end
  def add_products?
    return self.company.master? 
  end
  def edit_products?
    return self.company.master?
  end
  def create_products?
    return self.company.master?
  end
  
  def view_sales_orders?
    return master_setup.sales_order_enabled && (self.company.master? || self.company.customer?)
  end
  def add_sales_orders?
    return master_setup.sales_order_enabled && (self.company.master?)
  end
  def edit_sales_orders?
    return master_setup.sales_order_enabled && (self.company.master?)
  end
  
  def view_shipments?
    return master_setup.shipment_enabled && (self.company.master? || self.company.vendor? || self.company.carrier?)
  end
  def add_shipments?
    return master_setup.shipment_enabled && (self.company.master? || self.company.vendor? || self.company.carrier?)
  end
  def edit_shipments?
    return master_setup.shipment_enabled && (self.company.master? || self.company.vendor? || self.company.carrier?)
  end
  
  def view_deliveries?
    return master_setup.delivery_enabled && (self.company.master? || self.company.customer? || self.company.carrier?)
  end
  def add_deliveries?
    return master_setup.delivery_enabled && (self.company.master? || self.company.carrier?)
  end
  def edit_deliveries?
    return master_setup.delivery_enabled && (self.company.master? || self.company.carrier?)
  end

  def view_classifications?
    return master_setup.classification_enabled && (self.company.master? || self.company.vendor? || self.company.carrier?)
  end
  def add_classifications?
    return view_classifications? && self.company.master?
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

  private
  def master_setup
    MasterSetup.get
  end
end
