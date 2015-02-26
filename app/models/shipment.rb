class Shipment < ActiveRecord::Base
  include CoreObjectSupport
	belongs_to	:carrier, :class_name => "Company"
	belongs_to  :vendor,  :class_name => "Company"
	belongs_to	:ship_from,	:class_name => "Address"
	belongs_to	:ship_to,	:class_name => "Address"
  belongs_to :importer, :class_name=>"Company"
  belongs_to :lading_port, :class_name=>"Port"
  belongs_to :unlading_port, :class_name=>"Port"
  belongs_to :entry_port, :class_name=>"Port"
  belongs_to :destination_port, :class_name=>"Port"
  belongs_to :booking_requested_by, :class_name=>"User"
  belongs_to :booking_confirmed_by, :class_name=>"User"
  belongs_to :booking_approved_by, :class_name=>"User"
  belongs_to :canceled_by, :class_name=>"User"

	has_many   :shipment_lines, dependent: :destroy, inverse_of: :shipment, autosave: true
  has_many   :containers, dependent: :destroy, inverse_of: :shipment, autosave: true
  has_many   :piece_sets, :through=>:shipment_lines
  has_many   :carton_sets, dependent: :destroy, inverse_of: :shipment, autosave: true

	validates  :reference, :presence => true
  validates_uniqueness_of :reference

  dont_shallow_merge :Shipment, ['id','created_at','updated_at','vendor_id','reference']


  #########
  # Booking Request / Approve / Confirm / Revise
  #########
  def can_request_booking? user, ignore_shipment_state=false
    unless ignore_shipment_state
      return false if self.booking_received_date || self.booking_approved_date || self.booking_confirmed_date
    end
    return false unless self.can_view?(user)
    return false unless self.vendor == user.company || user.company.master?
    return true
  end
  def request_booking! user, async_snapshot = false
    self.booking_received_date = 0.seconds.ago
    self.booking_requested_by = user
    self.save!
    OpenChain::EventPublisher.publish :shipment_booking_request, self
    self.create_snapshot_with_async_option async_snapshot, user
  end
  def async_request_booking! user
    self.request_booking! user, true
  end

  def can_approve_booking? user, ignore_shipment_state=false
    unless ignore_shipment_state
      return false if self.booking_confirmed_date
      return false if self.booking_approved_date
      return false unless self.booking_received_date
    end
    return false unless self.can_edit?(user)
    return false unless self.importer == user.company || user.company.master?
    return true
  end
  def approve_booking! user, async_snapshot = false
    self.booking_approved_date = 0.seconds.ago
    self.booking_approved_by = user
    self.save!
    OpenChain::EventPublisher.publish :shipment_booking_approve, self
    self.create_snapshot_with_async_option async_snapshot, user
  end
  def async_approve_booking! user
    self.approve_booking! user, true
  end

  def can_confirm_booking? user, ignore_shipment_state=false
    unless ignore_shipment_state
      return false if self.booking_confirmed_date
      return false unless self.booking_received_date
    end
    return false unless self.can_edit?(user)
    return false unless self.carrier == user.company || user.company.master?
    return true
  end
  def confirm_booking! user, async_snapshot = false
    self.booking_confirmed_date = 0.seconds.ago
    self.booking_confirmed_by = user
    self.booked_quantity = self.shipment_lines.sum('quantity')
    self.save!
    OpenChain::EventPublisher.publish :shipment_booking_confirm, self
    self.create_snapshot_with_async_option async_snapshot, user
  end
  def async_confirm_booking! user
    self.confirm_booking! user, true
  end

  def can_revise_booking? user
    return false unless self.booking_approved_date || self.booking_confirmed_date
    if !self.booking_confirmed_date
      return true if self.can_approve_booking?(user,true) || self.can_request_booking?(user,true)
    else
      return true if self.can_confirm_booking?(user,true)
    end
    return false
  end
  def revise_booking! user, async_snapshot = false
    self.booking_approved_by = nil
    self.booking_approved_date = nil
    self.booking_confirmed_by = nil
    self.booking_confirmed_date = nil
    self.booking_received_date = nil
    self.booking_requested_by = nil
    self.save!
    self.create_snapshot_with_async_option async_snapshot, user
  end
  def async_revise_booking! user
    self.revise_booking! user, true
  end

  ###################
  # Cancel Shipment
  ###################
  def can_cancel? user
    return false if self.canceled_date
    return false unless self.can_edit?(user)
    return true if self.can_cancel_by_role?(user)
    return false
  end
  def cancel_shipment! user, async_snapshot = false
    Shipment.transaction do
      self.canceled_date = 0.seconds.ago
      self.canceled_by = user
      self.save!
      self.shipment_lines.each do |sl|
        sl.piece_sets.where('piece_sets.order_line_id IS NOT NULL').each do |ps|
          sl.canceled_order_line_id = ps.order_line_id
          sl.save!
          ps.order_line_id = nil
          if !ps.destroy_if_one_key
            ps.save!
            PieceSet.merge_duplicates! ps
          end
        end
      end
    end
    OpenChain::EventPublisher.publish :shipment_cancel, self
    self.create_snapshot_with_async_option async_snapshot, user
  end
  def async_cancel_shipment! user
    self.cancel_shipment! user, true
  end
  def can_uncancel? user
    return false unless self.canceled_date
    return false unless self.can_edit?(user)
    return true if self.can_cancel_by_role?(user)
    return false
  end
  def uncancel_shipment! user, async_snapshot = false
    Shipment.transaction do
      self.canceled_by = nil
      self.canceled_date = nil
      self.save!
      self.shipment_lines.where('shipment_lines.canceled_order_line_id is not null').each do |sl|
        ol_id = sl.canceled_order_line_id
        sl.canceled_order_line_id = nil
        sl.linked_order_line_id = ol_id
        sl.save!
      end
    end
    self.create_snapshot_with_async_option async_snapshot, user
  end
  def async_uncancel_shipment! user
    self.uncancel_shipment! user, true
  end

  #private support methods for can cancel
  def can_cancel_as_vendor? user
    (!self.booking_received_date) && user.company==self.vendor
  end
  private :can_cancel_as_vendor?
  def can_cancel_as_importer? user
    (!self.booking_confirmed_date) && user.company==self.importer
  end
  private :can_cancel_as_importer?
  def can_cancel_as_carrier? user
    user.company==self.carrier
  end
  private :can_cancel_as_carrier?
  def can_cancel_by_role? user
    return true if user.company.master?
    return true if can_cancel_as_vendor?(user)
    return true if can_cancel_as_importer?(user)
    return true if can_cancel_as_carrier?(user)
  end


  def find_same
    f = self.reference.nil? ? [] : Shipment.where(:reference=>self.reference.to_s)
    raise "Multiple shipments wtih reference \"#{self.reference} exist." if f.size > 1
    return f.empty? ? nil : f.first
  end

  #return all orders that could be added to this shipment and that the user can view
  def available_orders user
    return Order.where("1=0") if self.importer_id.blank? #can't find anything without an importer
    r = Order.search_secure(user,Order).where(importer_id:self.importer_id,approval_status:'Accepted').not_closed
    r = r.where(vendor_id:self.vendor_id) if self.vendor_id
    r
  end
  #get unique linked commercial invoices
  def commercial_invoices
    CommercialInvoice.
      joins(:commercial_invoice_lines=>[:piece_sets=>[:shipment_line]]).
      where("shipment_lines.shipment_id = ?",self.id).uniq
  end
	def self.modes
	  return ['Air','Sea','Truck','Rail','Parcel','Hand Carry','Other']
	end

	def can_view?(user)
    return false unless user.view_shipments?
    return true if user.company.master?
    imp = self.importer
    return false unless imp && (imp==user.company || imp.linked_company?(user.company))
	  return (user.company == self.vendor || user.company == self.carrier || user.company = self.importer || (self.vendor && self.vendor.linked_companies.include?(user.company)))
	end

	def can_edit?(user)
	  #same rules as view
	  return user.edit_shipments? && can_view?(user)
	end

  # can the user currently add lines to this shipment
  def can_add_remove_lines?(user)
    return false if self.booking_confirmed_date || self.booking_approved_date
    return self.can_edit?(user)
  end

  def can_comment?(user)
    return user.comment_shipments? && self.can_view?(user)
  end

  def can_attach?(user)
    return user.attach_shipments? && self.can_view?(user)
  end

	def locked?
	  (!self.vendor.nil? && self.vendor.locked?) ||
	  (!self.carrier.nil? && self.carrier.locked?)
	end

  def self.search_secure user, base_object
    base_object.where search_where user
  end

  def self.search_where user
    cid = user.company_id
    a = ['1=0']
    a << '1=1' if user.company.master
    a << "shipments.vendor_id = #{cid}"
    a << "shipments.vendor_id IN (SELECT parent_id FROM linked_companies WHERE child_id = #{cid})"
    a << "shipments.carrier_id = #{cid}"
    a << "shipments.importer_id = #{cid}"
    "(#{a.join(" OR ")})"
  end
end
