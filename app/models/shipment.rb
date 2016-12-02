require 'open_chain/order_booking_registry'
class Shipment < ActiveRecord::Base
  include CoreObjectSupport
  include ISFSupport
	belongs_to	:carrier, :class_name => "Company"
	belongs_to  :vendor,  :class_name => "Company"
  belongs_to  :forwarder, :class_name => "Company"
	belongs_to	:ship_from,	:class_name => "Address"
	belongs_to	:ship_to,	:class_name => "Address"
  belongs_to :importer, :class_name=>"Company"
  belongs_to :lading_port, :class_name=>"Port"
  belongs_to :unlading_port, :class_name=>"Port"
  belongs_to :entry_port, :class_name=>"Port"
  belongs_to :destination_port, :class_name=>"Port"
  belongs_to :final_dest_port, :class_name=>"Port"
  belongs_to :booking_first_port_receipt, :class_name => "Port"
  belongs_to :first_port_receipt, :class_name => "Port"
  belongs_to :last_foreign_port, :class_name => "Port"
  belongs_to :inland_destination_port, :class_name => "Port"
  belongs_to :booking_requested_by, :class_name=>"User"
  belongs_to :booking_confirmed_by, :class_name=>"User"
  belongs_to :booking_approved_by, :class_name=>"User"
  belongs_to :canceled_by, :class_name=>"User"
  belongs_to :cancel_requested_by, :class_name=>"User"
  belongs_to :cancel_approved_by, :class_name=>"User"
  belongs_to :consignee, :class_name=>"Company"
  belongs_to :isf_sent_by, :class_name => "User"
  belongs_to :booking_revised_by, :class_name => "User"
  belongs_to :shipment_instructions_sent_by, :class_name => "User"

	has_many   :shipment_lines, dependent: :destroy, inverse_of: :shipment, autosave: true
  has_many   :booking_lines, dependent: :destroy, inverse_of: :shipment, autosave: true
  has_many   :containers, dependent: :destroy, inverse_of: :shipment, autosave: true
  has_many   :piece_sets, :through=>:shipment_lines
  has_many   :carton_sets, dependent: :destroy, inverse_of: :shipment, autosave: true

	validates  :reference, :presence => true
  validates_uniqueness_of :reference

  dont_shallow_merge :Shipment, ['id','created_at','updated_at','vendor_id','reference']

  # Generate a pseudo-unique reference number
  # Number is checked against the reference field in the database for uniqueness
  # before it is retured, but it does not lock, so there is a small chance of collision
  # between generate_reference and saving the object.
  #
  # As of 2016-09-05, the returned value is an 8 digit hex, so there are over 4 billion possible values
  # which should limit collisions
  def self.generate_reference
    ref = nil
    while !ref
      rand = SecureRandom.hex(4).upcase
      ref = rand if Shipment.where(reference:rand).empty?
    end
    ref
  end

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
    self.booking_request_count ||= 0
    self.booking_request_count = (self.booking_request_count + 1)
    OpenChain::OrderBookingRegistry.registered.each {|obr| obr.request_booking_hook(self,user)}
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
    registered = OpenChain::OrderBookingRegistry.registered
    if registered.empty?
      # Can't revise bookings that have shipment lines
      return false if self.shipment_lines.try(:size) > 0
      # Can't revise bookings that haven't been confirmed or approved
      return false unless self.booking_approved_date || self.booking_confirmed_date

      if !self.booking_confirmed_date
        # Users that can request or approve bookings can revise if it's not confirmed
        return true if self.can_approve_booking?(user,true) || self.can_request_booking?(user,true)
      else
        # If there's a booking confirm date, only user's that can confirm can revise a booking
        return true if self.can_confirm_booking?(user,true)
      end
      return false
    else
      registered.each do |r|
        return false unless r.can_revise_booking_hook(self,user)
      end
      return true
    end
  end
  def revise_booking! user, async_snapshot = false
    # Booking data gets revised all the time apparently before its actually on-boarded, so while we clear
    # the approval/confirmation info, we don't want to clear the initial receipt/request info.
    self.booking_approved_by = nil
    self.booking_approved_date = nil
    self.booking_confirmed_by = nil
    self.booking_confirmed_date = nil
    self.booking_revised_date = Time.zone.now.to_date
    self.booking_revised_by = user
    self.booking_request_count ||= 0
    self.booking_request_count = (self.booking_request_count + 1)
    OpenChain::OrderBookingRegistry.registered.each {|obr| obr.revise_booking_hook(self,user)}
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
      self.cancel_requested_at = nil
      self.cancel_requested_by = nil
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

  def can_request_cancel? user, ignore_shipment_state=false
    unless ignore_shipment_state
      return false if self.canceled_date || self.cancel_requested_at
    end
    return false unless self.can_view?(user)
    return false unless self.vendor == user.company || user.company.master?
    return true
  end
  def request_cancel! user, async_snapshot = false
    self.cancel_requested_at = 0.seconds.ago
    self.cancel_requested_by = user
    self.save!
    OpenChain::EventPublisher.publish :shipment_cancel_request, self
    self.create_snapshot_with_async_option async_snapshot, user
    OpenChain::OrderBookingRegistry.registered.each {|obr| obr.post_request_cancel_hook(self,user)}
  end
  def async_request_cancel! user
    self.request_cancel! user, true
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

  ###################
  # Shipment Instructions
  ###################
  def can_send_shipment_instructions? user
    return false unless self.booking_received_date
    return false if self.canceled_date
    return false unless user.company == self.vendor
    return false unless self.can_edit?(user)
    return false if self.shipment_lines.empty?
    return true
  end
  def send_shipment_instructions! user, async_snapshot = false
    self.shipment_instructions_sent_date = 0.seconds.ago
    self.shipment_instructions_sent_by = user
    self.save!
    OpenChain::EventPublisher.publish :shipment_instructions_send, self
    self.create_snapshot_with_async_option async_snapshot, user
  end
  def async_send_shipment_instructions! user
    self.send_shipment_instructions! user, true
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

  def available_products user
    return Product.where("1=0") if self.importer_id.blank? #can't find anything without an importer
    p = Product.search_secure(user, Product).where(importer_id: self.importer_id)
  end

  #get unique linked commercial invoices
  def commercial_invoices
    CommercialInvoice.
      joins(:commercial_invoice_lines=>[:piece_sets=>[:shipment_line]]).
      where("shipment_lines.shipment_id = ?",self.id).uniq
  end
	def self.modes
    # These are deprecated old modes...don't reference for the new screen
	  return ['Air','Sea','Truck','Rail','Parcel','Hand Carry','Other']
	end

  def ocean?
    ['OCEAN - LCL', 'OCEAN - FCL'].include? self.mode.to_s.upcase
  end

  def air?
    'AIR' == self.mode.to_s.upcase
  end

	def can_view?(user)
    return false unless user.view_shipments?
    return true if user.company.master?
    imp = self.importer
    return false if imp.blank?
    # company must be linked to the importer to see a shipment regardless of whether it is a party
    return false if imp!=user.company && !imp.linked_company?(user.company)
    return (
      user.company == self.vendor ||
      user.company == self.carrier ||
      user.company == self.importer ||
      user.company == self.forwarder ||
      (self.vendor && self.vendor.linked_companies.include?(user.company))
    )
	end

	def can_edit?(user)
	  #same rules as view
	  return user.edit_shipments? && can_view?(user)
	end

  # can the user currently add lines to this shipment
  def can_add_remove_shipment_lines?(user)
    return self.can_edit?(user)
  end

  def can_add_remove_booking_lines?(user)
    # At any point up till there are actual manifest/shipment lines users w/ edit ability
    # can remove shipment lines.
    return false if self.shipment_lines.length > 0
    return self.can_edit?(user)
  end

  def can_comment?(user)
    return user.comment_shipments? && self.can_view?(user)
  end

  def can_attach?(user)
    return user.attach_shipments? && self.can_view?(user)
  end

  def can_book?
    self.booking_received_date.nil?
  end

	def locked?
	  (!self.vendor.nil? && self.vendor.locked?) ||
	  (!self.carrier.nil? && self.carrier.locked?)
  end

  def dimensional_weight
    (self.volume / 0.006).round(2) if self.volume
  end

  def chargeable_weight
    (dimensional_weight || 0) > (self.gross_weight || 0) ? dimensional_weight : self.gross_weight
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
    a << "shipments.forwarder_id = #{cid}"
    "(#{a.join(" OR ")})"
  end

  def enabled_booking_types
    # ['product','order','order_line','container']
    self.importer.try(:enabled_booking_types_array) || []
  end

  def mark_isf_sent!(user, async_snapshot=false)
    self.isf_sent_at = 0.seconds.ago
    self.isf_sent_by = user
    save!
    self.create_snapshot_with_async_option async_snapshot, user
  end
end
