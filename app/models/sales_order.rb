class SalesOrder < ActiveRecord::Base
  include OrderSupport
	include CustomFieldSupport
  include ShallowMerger
  include EntitySnapshotSupport

  belongs_to :customer, :class_name => "Company"
  belongs_to :division
  belongs_to :ship_to, :class_name => "Address"
  
  has_many    :histories, :dependent => :destroy
  has_many    :item_change_subscriptions, :dependent => :destroy
  has_many    :sales_order_lines, :dependent => :destroy
  has_many   :comments, :as => :commentable, :dependent => :destroy
  has_many   :attachments, :as => :attachable, :dependent => :destroy

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
  def locked?
    !self.customer.nil? && self.customer.locked?
  end

  #gets a list of unique products on the order
  
	def self.search_secure user, base_object
    if user.company.master
      return base_object.where("1=1")
    elsif user.company.customer?
      return base_object.where(:customer_id => user.company)
    else
      return base_object.where("1=0")
    end
  end

  private
  #needed for OrderSupport mixin
  def get_lines
    self.sales_order_lines
  end  
end
