class User < ActiveRecord::Base
  acts_as_authentic
  
  belongs_to :company
  
  has_many   :histories, :dependent => :destroy
  has_many   :item_change_subscriptions, :dependent => :destroy
  has_many   :search_setups, :dependent => :destroy
  has_many   :messages
  
  validates  :company, :presence => true
  
  def self.find_not_locked(login) 
    u = User.where(:username => login).first
    unless u.nil? || u.company.locked
      return u
    else
      return nil
    end
  end
  
  def active?
    return !self.disabled
  end
  
  def full_name
    n = (self.first_name.nil? ? '' : self.first_name + " ") + (self.last_name.nil? ? '' : self.last_name)
    n = self.username if n.strip.length==0
    return n
  end
  
  def can_view?(user)
    return user.company.master || self==user
  end
  
  def can_edit?(user)
    return user.company.master || self==user
  end
  
  #permissions
  def view_orders?
    return self.company.master? || self.company.vendor?
  end
  def add_orders?
    return self.company.master?
  end
  def edit_orders?
    return self.company.master?
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
  
  def view_sales_orders?
    return self.company.master? || self.company.customer?
  end
  def add_sales_orders?
    return self.company.master?
  end
  def edit_sales_orders?
    return self.company.master?
  end
  
  def view_shipments?
    return self.company.master? || self.company.vendor? || self.company.carrier?
  end
  def add_shipments?
    return self.company.master? || self.company.vendor? || self.company.carrier?
  end
  def edit_shipments?
    return self.company.master? || self.company.vendor? || self.company.carrier?
  end
  
  def view_deliveries?
    return self.company.master? || self.company.customer? || self.company.carrier?
  end
  def add_deliveries?
    return self.company.master? || self.company.carrier?
  end
  def edit_deliveries?
    return self.company.master? || self.company.carrier?
  end
  
  def edit_milestone_plans?
    return self.company.master?
  end
  
  def edit_status_rules?
    return self.company.master?
  end
end
