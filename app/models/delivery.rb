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
  has_many   :attachments, :as => :attachable

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

	def self.search_secure user, base_object
    if user.company.master
      return base_object.where("1=1")
    elsif user.company.carrier
      return base_object.where(:carrier_id => user.company)
    elsif user.company.customer
      return base_object.where(:customer_id => user.company)
    else
      return base_object.where("1=0")
    end
  end
end
