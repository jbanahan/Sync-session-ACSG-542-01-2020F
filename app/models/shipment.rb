class Shipment < ActiveRecord::Base
	include CustomFieldSupport
  include ShallowMerger
  include EntitySnapshotSupport
	
	belongs_to	:carrier, :class_name => "Company"
	belongs_to  :vendor,  :class_name => "Company"
	belongs_to	:ship_from,	:class_name => "Address"
	belongs_to	:ship_to,	:class_name => "Address"
	
	has_many   :shipment_lines, :dependent => :destroy
  has_many   :histories, :dependent => :destroy
  has_many   :comments, :as => :commentable, :dependent => :destroy
  has_many   :item_change_subscriptions, :dependent => :destroy
  has_many   :attachments, :as => :attachable, :dependent => :destroy

  validates  :vendor, :presence => true
	validates  :reference, :presence => true
  validates_uniqueness_of :reference, {:scope => :vendor_id}

  dont_shallow_merge :Shipment, ['id','created_at','updated_at','vendor_id','reference']
  def find_same
    f = self.reference.nil? ? [] : Shipment.where(:reference=>self.reference.to_s).where(:vendor_id=>self.vendor_id)
    raise "Multiple shipments wtih reference \"#{self.reference} and vendor ID #{self.vendor_id} exist." if f.size > 1
    return f.empty? ? nil : f.first
  end

	def self.modes 
	  return ['Air','Sea','Truck','Rail','Parcel','Hand Carry','Other']
	end
	

	def can_view?(user)
	  return user.view_shipments? && (user.company.master? || (user.company.vendor? && user.company == self.vendor) || (user.company.carrier? && user.company == self.carrier))
	end
	
	def can_edit?(user)
	  #same rules as view
	  return can_view? user
	end
	
	def locked?
	  (!self.vendor.nil? && self.vendor.locked?) ||
	  (!self.carrier.nil? && self.carrier.locked?)
	end
	

private
	def self.search_secure user, base_object
    if user.company.master
      return base_object.where("1=1")
    elsif user.company.vendor 
      return base_object.where(:vendor_id => user.company)
    elsif user.company.carrier
      return base_object.where(:carrier_id => user.company)
    else
      return base_object.where("1=0")
    end
  end
end
