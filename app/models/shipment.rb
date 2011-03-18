class Shipment < ActiveRecord::Base
	include CustomFieldSupport
  include ShallowMerger
	
	belongs_to	:carrier, :class_name => "Company"
	belongs_to  :vendor,  :class_name => "Company"
	belongs_to	:ship_from,	:class_name => "Address"
	belongs_to	:ship_to,	:class_name => "Address"
	
	has_many   :piece_sets, :dependent => :destroy
  has_many   :histories, :dependent => :destroy
  has_many   :order_lines, :through => :piece_sets
  has_many   :comments, :as => :commentable
  has_many   :item_change_subscriptions
  has_many   :attachments, :as => :attachable

  validates  :vendor, :presence => true
	validates  :reference, :presence => true
  validates_uniqueness_of :reference, {:scope => :vendor_id}

  dont_shallow_merge :Shipment, ['id','created_at','updated_at','vendor_id','reference']
  def find_same
    f = Shipment.where(:reference=>self.reference).where(:vendor_id=>self.vendor_id)
    raise "Multiple shipments wtih reference \"#{self.reference} and vendor ID #{self.vendor_id} exist." if f.size > 1
    return f.empty? ? nil : f.first
  end

	def self.modes 
	  return ['Air','Sea','Truck','Rail','Parcel','Hand Carry','Other']
	end
	
  #receive an set order line from the shipment into inventory
  #takes a hash with order line as the key and the quantity to receive as the value
  def receive(ord_line_qty_hash)
    inv = InventoryIn.create!
    ord_line_qty_hash.each do |line,qty|
      ps = find_matching_piece_set line, qty
      if ps.quantity == qty
        ps.inventory_in = inv
      elsif ps.quantity > qty #undershipped
        new_ps = ps.clone
        new_ps.quantity = qty #make new piece set for short shipment
        new_ps.inventory_in = inv
        new_ps.save!
        ps.quantity = ps.quantity - qty #leave remainder
      elsif ps.quantity < qty #overshipped
        new_ps = ps.clone
        new_ps.quantity = qty - ps.quantity #make new piece set for overage
        new_ps.inventory_in = inv
        new_ps.adjustment_type = "Excess Receipt"
        new_ps.save!
        ps.inventory_in = inv #both sets are received into inventory
      end
      ps.save!
    end
    return inv
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
	
	def update_unshipped_quantities
	  self.piece_sets.each do |p|
	    unless p.order_line.nil?
	      p.order_line.make_unshipped_remainder_piece_set.save
	    end
	  end
	end

private
  def find_matching_piece_set(order_line,quantity)
    #pass 1, look for exact quantity match
    potential_matches = self.piece_sets.where(:order_line_id => order_line.id, 
        :inventory_in_id => nil, :quantity => quantity)
    matching_ps = potential_matches.first

    #pass 2, look for matches with more quantity available
    if matching_ps.nil?
      matching_ps = self.piece_sets.where(:order_line_id => order_line.id,
        :inventory_in_id => nil).where("quantity > ?",quantity).first
    end

    #pass 3, look for matches with less quantity available
    if matching_ps.nil?
      matching_ps = self.piece_sets.where(:order_line_id => order_line.id,
        :inventory_in_id => nil).where("quantity < ?",quantity).first
    end
    
    #create a new piece set to receive against (didn't find any matches),
    #and mark as over receipt
    if matching_ps.nil?
      matching_ps = self.piece_sets.build(:order_line_id => order_line.id,
        :quantity => quantity, :adjustment_type => "Unmatched Receipt",
        :product_id => order_line.product_id)
    end

    return matching_ps
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
