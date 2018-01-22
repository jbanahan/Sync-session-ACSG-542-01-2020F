# == Schema Information
#
# Table name: shipments
#
#  id                               :integer          not null, primary key
#  ship_from_id                     :integer
#  ship_to_id                       :integer
#  carrier_id                       :integer
#  created_at                       :datetime
#  updated_at                       :datetime
#  reference                        :string(255)
#  mode                             :string(255)
#  vendor_id                        :integer
#  importer_id                      :integer
#  master_bill_of_lading            :string(255)
#  house_bill_of_lading             :string(255)
#  booking_number                   :string(255)
#  receipt_location                 :string(255)
#  lading_port_id                   :integer
#  unlading_port_id                 :integer
#  entry_port_id                    :integer
#  destination_port_id              :integer
#  freight_terms                    :string(255)
#  lcl                              :boolean
#  shipment_type                    :string(255)
#  booking_shipment_type            :string(255)
#  booking_mode                     :string(255)
#  vessel                           :string(255)
#  voyage                           :string(255)
#  vessel_carrier_scac              :string(255)
#  booking_received_date            :datetime
#  booking_confirmed_date           :datetime
#  booking_cutoff_date              :date
#  booking_est_arrival_date         :date
#  booking_est_departure_date       :date
#  docs_received_date               :date
#  cargo_on_hand_date               :date
#  est_departure_date               :date
#  departure_date                   :date
#  est_arrival_port_date            :date
#  arrival_port_date                :date
#  est_delivery_date                :date
#  delivered_date                   :date
#  cargo_on_board_date              :date
#  last_exported_from_source        :datetime
#  importer_reference               :string(255)
#  cargo_ready_date                 :date
#  booking_requested_by_id          :integer
#  booking_confirmed_by_id          :integer
#  booking_approved_date            :datetime
#  booking_approved_by_id           :integer
#  booked_quantity                  :decimal(11, 2)
#  canceled_date                    :datetime
#  canceled_by_id                   :integer
#  vessel_nationality               :string(255)
#  first_port_receipt_id            :integer
#  last_foreign_port_id             :integer
#  marks_and_numbers                :text
#  number_of_packages               :integer
#  number_of_packages_uom           :string(255)
#  gross_weight                     :decimal(9, 2)
#  booking_carrier                  :string(255)
#  booking_vessel                   :string(255)
#  delay_reason_codes               :string(255)
#  shipment_cutoff_date             :date
#  fish_and_wildlife                :boolean
#  volume                           :decimal(9, 2)
#  cancel_requested_at              :datetime
#  cancel_requested_by_id           :integer
#  seller_address_id                :integer
#  buyer_address_id                 :integer
#  ship_to_address_id               :integer
#  container_stuffing_address_id    :integer
#  consolidator_address_id          :integer
#  consignee_id                     :integer
#  isf_sent_at                      :datetime
#  isf_sent_by_id                   :integer
#  est_load_date                    :date
#  final_dest_port_id               :integer
#  confirmed_on_board_origin_date   :date
#  eta_last_foreign_port_date       :date
#  departure_last_foreign_port_date :date
#  booking_revised_date             :datetime
#  booking_revised_by_id            :integer
#  freight_total                    :decimal(11, 2)
#  invoice_total                    :decimal(11, 2)
#  inland_destination_port_id       :integer
#  est_inland_port_date             :date
#  inland_port_date                 :date
#  asn_triggered_at                 :datetime
#  asn_triggered_by_id              :integer
#  asn_sent_at                      :datetime
#  requested_equipment              :text
#  forwarder_id                     :integer
#  booking_cargo_ready_date         :date
#  booking_first_port_receipt_id    :integer
#  booking_requested_equipment      :string(255)
#  booking_request_count            :integer
#  hazmat                           :boolean
#  solid_wood_packing_materials     :boolean
#  lacey_act                        :boolean
#  export_license_required          :boolean
#  shipment_instructions_sent_date  :date
#  shipment_instructions_sent_by_id :integer
#  last_file_bucket                 :string(255)
#  last_file_path                   :string(255)
#  do_issued_at                     :date
#  trucker_name                     :string(255)
#  port_last_free_day               :date
#  pickup_at                        :date
#  in_warehouse_time                :datetime
#
# Indexes
#
#  index_shipments_on_arrival_port_date           (arrival_port_date)
#  index_shipments_on_booking_approved_by_id      (booking_approved_by_id)
#  index_shipments_on_booking_cargo_ready_date    (booking_cargo_ready_date)
#  index_shipments_on_booking_confirmed_by_id     (booking_confirmed_by_id)
#  index_shipments_on_booking_number              (booking_number)
#  index_shipments_on_booking_request_count       (booking_request_count)
#  index_shipments_on_booking_requested_by_id     (booking_requested_by_id)
#  index_shipments_on_canceled_by_id              (canceled_by_id)
#  index_shipments_on_canceled_date               (canceled_date)
#  index_shipments_on_departure_date              (departure_date)
#  index_shipments_on_est_arrival_port_date       (est_arrival_port_date)
#  index_shipments_on_est_departure_date          (est_departure_date)
#  index_shipments_on_forwarder_id                (forwarder_id)
#  index_shipments_on_house_bill_of_lading        (house_bill_of_lading)
#  index_shipments_on_importer_id                 (importer_id)
#  index_shipments_on_importer_reference          (importer_reference)
#  index_shipments_on_inland_destination_port_id  (inland_destination_port_id)
#  index_shipments_on_master_bill_of_lading       (master_bill_of_lading)
#  index_shipments_on_mode                        (mode)
#  index_shipments_on_reference                   (reference)
#

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
    registered = OpenChain::OrderBookingRegistry.registered
    if registered.empty?
      return default_can_request_booking?(user, ignore_shipment_state)
    else
      registered.each do |r|
        return false unless r.can_request_booking?(self,user)
      end
      return true
    end
  end

  def default_can_request_booking? user, ignore_shipment_state=false
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
        return true if self.can_approve_booking?(user,true) || self.default_can_request_booking?(user,true)
      else
        # If there's a booking confirm date, only user's that can confirm can revise a booking
        return true if self.can_confirm_booking?(user,true)
      end
      return false
    else
      registered.each do |r|
        return false unless r.can_revise_booking?(self,user)
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
    self.booking_revised_date = Time.zone.now
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

  def can_edit_booking? user
    registered = OpenChain::OrderBookingRegistry.registered
    if registered.empty?
      # By default, just use the can_edit shipment register
      return can_edit?(user)
    else
      registered.each do |r|
        return false unless r.can_edit_booking?(self,user)
      end
      return true
    end
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
