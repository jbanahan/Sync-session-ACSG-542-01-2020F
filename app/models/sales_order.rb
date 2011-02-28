class SalesOrder < ActiveRecord::Base
  include OrderSupport
	include CustomFieldSupport
  
  belongs_to :customer, :class_name => "Company"
  belongs_to :division
  belongs_to :ship_to, :class_name => "Address"
  
  has_many    :histories, :dependent => :destroy
  has_many    :item_change_subscriptions
  has_many    :sales_order_lines, :dependent => :destroy
  has_many   :comments, :as => :commentable
  has_many   :attachments, :as => :attachable

  validates :customer, :presence => true

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
  def unique_products
    p_hash = {}
    self.sales_order_lines.each do |line|
      prod = line.product
      if p_hash[prod.id].nil?
        prod.instance_variable_set(:@ordered_qty, line.ordered_qty)
        p_hash[prod.id] = prod
      else
        pe = p_hash[prod.id]
        pe.instance_variable_set(:@ordered_qty, pe.instance_variable_get(:@ordered_qty)+line.ordered_qty)
      end
    end
    return p_hash.values
  end
  
  private
  #needed for OrderSupport mixin
  def get_lines
    self.sales_order_lines
  end  
end
