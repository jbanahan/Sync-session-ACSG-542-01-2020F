class SalesOrder < ActiveRecord::Base
  include CoreObjectSupport

  belongs_to :customer, :class_name => "Company"
  belongs_to :division
  belongs_to :ship_to, :class_name => "Address"
  
  has_many    :sales_order_lines, :dependent => :destroy
  has_many    :piece_sets, :through => :sales_order_lines
  validates :customer, :presence => true

  dont_shallow_merge :SalesOrder, ['id','created_at','updated_at','order_number']

  def find_same
    found = self.order_number.nil? ? [] : SalesOrder.where(:order_number => self.order_number.to_s)
    raise "Found multiple sales with the same order number #{self.order_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end

  def can_view?(user)
    user.view_sales_orders? && (user.company.master || (!self.customer.nil? && user.company.customer && user.company==self.customer))
  end
  def can_edit?(user)
    user.edit_sales_orders? && user.company.master 
  end
  def can_comment?(user)
    user.comment_sales_orders? && can_view?(user)
  end
  def can_attach?(user)
    user.attach_sales_orders? && can_view?(user)
  end
  def locked?
    !self.customer.nil? && self.customer.locked?
  end

  #gets a list of unique products on the order
  
	def self.search_secure user, base_object
    base_object.where search_where user
  end

  def self.search_where user
    if user.company.master
      return "1=1"
    elsif user.company.customer?
      return "sales_orders.customer_id = #{user.company_id}"
    else
      return "1=0"
    end
  end
end
