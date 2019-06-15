# == Schema Information
#
# Table name: deliveries
#
#  carrier_id   :integer
#  created_at   :datetime         not null
#  customer_id  :integer
#  id           :integer          not null, primary key
#  mode         :string(255)
#  reference    :string(255)
#  ship_from_id :integer
#  ship_to_id   :integer
#  updated_at   :datetime         not null
#

class Delivery < ActiveRecord::Base
  
  include CoreObjectSupport

  attr_accessible :carrier_id, :customer_id, :mode, :reference, :ship_from_id, 
    :ship_to_id

  belongs_to  :carrier, :class_name => "Company"
  belongs_to  :customer,  :class_name => "Company"
  belongs_to  :ship_from, :class_name => "Address"
  belongs_to  :ship_to, :class_name => "Address"
  
  has_many   :sales_order_lines, :through => :piece_sets
  has_many   :delivery_lines, :dependent => :destroy

  validates :customer, :presence => true
  validates :reference, :presence => true
  validates_uniqueness_of :reference, {:scope => :customer_id}

  dont_shallow_merge :Delivery, ['id','created_at','updated_at','customer_id','reference']
  def find_same
    f = self.reference.nil? ? [] : Delivery.where(:reference=>self.reference.to_s).where(:customer_id=>self.customer_id)
    raise "Multiple deliveries with reference \"#{self.reference} and customer ID #{self.customer_id} exist." if f.size > 1
    return f.empty? ? nil : f.first
  end

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
  def can_comment?(user)
    user.comment_deliveries? && can_view?(user)
  end
  def can_attach?(user)
    user.attach_deliveries? && can_view?(user)
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

  def self.search_where user
    if user.company.master
      return "1=1"
    elsif user.company.carrier
      return "deliveries.carrier_id = #{user.company_id}"
    elsif user.company.customer
      return "deliveries.customer_id = #{user.company_id}"
    else
      return "1=0"
    end
  end
end
