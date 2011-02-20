class Delivery < ActiveRecord::Base
  
	include CustomFieldSupport
	
  belongs_to  :carrier, :class_name => "Company"
  belongs_to  :customer,  :class_name => "Company"
  belongs_to  :ship_from, :class_name => "Address"
  belongs_to  :ship_to, :class_name => "Address"
  
  has_many   :piece_sets, :dependent => :destroy
  has_many   :histories, :dependent => :destroy
  has_many   :sales_order_lines, :through => :piece_sets
  has_many   :comments, :as => :commentable
  
  def can_edit?(user)
    user.edit_deliveries? && (
    user.company.master? || 
    (!self.carrier.nil? && self.carrier==user.company) )
  end
  def can_view?(user)
    user.view_deliveries? && (
    user.company.master? || 
    (!self.carrier.nil? && self.carrier==user.company) ||
    (!self.customer.nil? && self.customer==user.company) )
  end
  def locked? 
    (!self.carrier.nil? && self.carrier.locked?) ||
    (!self.customer.nil? && self.customer.locked?)
  end
end
