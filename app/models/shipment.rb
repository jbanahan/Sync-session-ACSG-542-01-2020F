class Shipment < ActiveRecord::Base
	include CustomFieldSupport
	
	belongs_to	:carrier, :class_name => "Company"
	belongs_to  :vendor,  :class_name => "Company"
	belongs_to	:ship_from,	:class_name => "Address"
	belongs_to	:ship_to,	:class_name => "Address"
	
	has_many   :piece_sets, :dependent => :destroy
  has_many   :histories, :dependent => :destroy
  has_many   :order_lines, :through => :piece_sets
  has_many   :item_change_subscriptions

  validates   :vendor, :presence => true
	
	def self.modes 
	  return ['Air','Sea','Truck','Rail','Parcel','Hand Carry','Other']
	end
	
	def can_view?(user)
	  return user.company.master? || (user.company.vendor? && user.company == self.vendor) || (user.company.carrier? && user.company == self.carrier)
	end
	
	def can_edit?(user)
	  #same rules as view
	  return can_view? user
	end
	
	def locked?
	  (!self.vendor.nil? && self.vendor.locked?) ||
	  (!self.carrier.nil? && self.carrier.locked?)
	end
	
	def update_unshipped_quantities
	  self.piece_sets.each do |p|
	    unless p.order_line.nil?
	      p.order_line.make_unshipped_remainder_piece_set.save
	    end
	  end
	end
	
end
