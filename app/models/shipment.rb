# == Schema Information
#
# Table name: shipments
#
#  arrival_port_date                :date
#  arrive_at_transship_port_date    :datetime
#  available_for_delivery_date      :datetime
#  barge_arrive_date                :datetime
#  barge_depart_date                :datetime
#  bol_date                         :datetime
#  booked_quantity                  :decimal(11, 2)
#  booking_approved_by_id           :integer
#  booking_approved_date            :datetime
#  booking_cargo_ready_date         :date
#  booking_carrier                  :string(255)
#  booking_confirmed_by_id          :integer
#  booking_confirmed_date           :datetime
#  booking_cutoff_date              :date
#  booking_est_arrival_date         :date
#  booking_est_departure_date       :date
#  booking_first_port_receipt_id    :integer
#  booking_mode                     :string(255)
#  booking_number                   :string(255)
#  booking_received_date            :datetime
#  booking_request_count            :integer
#  booking_requested_by_id          :integer
#  booking_requested_equipment      :string(255)
#  booking_revised_by_id            :integer
#  booking_revised_date             :datetime
#  booking_shipment_type            :string(255)
#  booking_vessel                   :string(255)
#  booking_voyage                   :string(255)
#  buyer_address_id                 :integer
#  cancel_requested_at              :datetime
#  cancel_requested_by_id           :integer
#  canceled_by_id                   :integer
#  canceled_date                    :datetime
#  cargo_on_board_date              :date
#  cargo_on_hand_date               :date
#  cargo_ready_date                 :date
#  carrier_id                       :integer
#  carrier_released_date            :datetime
#  confirmed_on_board_origin_date   :date
#  consignee_id                     :integer
#  consolidator_address_id          :integer
#  container_stuffing_address_id    :integer
#  container_unloaded_date          :datetime
#  country_export_id                :integer
#  country_import_id                :integer
#  country_origin_id                :integer
#  created_at                       :datetime         not null
#  customs_released_carrier_date    :datetime
#  delay_reason_codes               :string(255)
#  delivered_date                   :date
#  departure_date                   :date
#  departure_last_foreign_port_date :date
#  description_of_goods             :string(255)
#  destination_port_id              :integer
#  do_issued_at                     :date
#  docs_received_date               :date
#  empty_out_at_origin_date         :datetime
#  empty_return_date                :datetime
#  entry_port_id                    :integer
#  est_arrival_port_date            :date
#  est_delivery_date                :date
#  est_departure_date               :date
#  est_inland_port_date             :date
#  est_load_date                    :date
#  eta_last_foreign_port_date       :date
#  export_license_required          :boolean
#  fcr_created_final_date           :datetime
#  final_dest_port_id               :integer
#  first_port_receipt_id            :integer
#  fish_and_wildlife                :boolean
#  forwarder_id                     :integer
#  freight_terms                    :string(255)
#  freight_total                    :decimal(11, 2)
#  full_container_discharge_date    :datetime
#  full_ingate_date                 :datetime
#  full_out_gate_discharge_date     :datetime
#  gross_weight                     :decimal(9, 2)
#  hazmat                           :boolean
#  house_bill_of_lading             :string(255)
#  id                               :integer          not null, primary key
#  importer_id                      :integer
#  importer_reference               :string(255)
#  in_warehouse_time                :datetime
#  inland_destination_port_id       :integer
#  inland_port_date                 :date
#  invoice_total                    :decimal(11, 2)
#  isf_sent_at                      :datetime
#  isf_sent_by_id                   :integer
#  lacey_act                        :boolean
#  lading_port_id                   :integer
#  last_exported_from_source        :datetime
#  last_file_bucket                 :string(255)
#  last_file_path                   :string(255)
#  last_foreign_port_id             :integer
#  lcl                              :boolean
#  marks_and_numbers                :text(65535)
#  master_bill_of_lading            :string(255)
#  mode                             :string(255)
#  number_of_packages               :integer
#  number_of_packages_uom           :string(255)
#  on_rail_destination_date         :datetime
#  packing_list_sent_by_id          :integer
#  packing_list_sent_date           :datetime
#  pickup_at                        :date
#  port_last_free_day               :date
#  receipt_location                 :string(255)
#  reference                        :string(255)
#  requested_equipment              :text(65535)
#  seller_address_id                :integer
#  ship_from_id                     :integer
#  ship_to_address_id               :integer
#  ship_to_id                       :integer
#  shipment_cutoff_date             :date
#  shipment_instructions_sent_by_id :integer
#  shipment_instructions_sent_date  :date
#  shipment_type                    :string(255)
#  solid_wood_packing_materials     :boolean
#  trucker_name                     :string(255)
#  unlading_port_id                 :integer
#  updated_at                       :datetime         not null
#  vendor_id                        :integer
#  vessel                           :string(255)
#  vessel_carrier_scac              :string(255)
#  vessel_nationality               :string(255)
#  vgm_sent_by_id                   :integer
#  vgm_sent_date                    :datetime
#  volume                           :decimal(9, 2)
#  voyage                           :string(255)
#  warning_overridden_at            :datetime
#  warning_overridden_by_id         :integer
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

require 'open_chain/registries/order_booking_registry'
require 'open_chain/registries/shipment_registry'

class Shipment < ActiveRecord::Base
  include CoreObjectSupport
  include ISFSupport
  include IntegrationParserSupport

  attr_accessible :arrival_port_date, :arrive_at_transship_port_date, 
    :available_for_delivery_date, :barge_arrive_date, :barge_depart_date, 
    :bol_date, :booked_quantity, :booking_approved_by_id, 
    :booking_approved_date, :booking_cargo_ready_date, :booking_carrier, 
    :booking_confirmed_by_id, :booking_confirmed_date, :booking_cutoff_date, 
    :booking_est_arrival_date, :booking_est_departure_date, 
    :booking_first_port_receipt_id, :booking_mode, :booking_number, 
    :booking_received_date, :booking_request_count, :booking_requested_by_id, :booking_requested_by,
    :booking_requested_equipment, :booking_revised_by_id, :booking_revised_date, 
    :booking_shipment_type, :booking_vessel, :booking_voyage, :buyer_address_id, :buyer_address,
    :cancel_requested_at, :cancel_requested_by_id, :canceled_by_id, 
    :canceled_date, :cargo_on_board_date, :cargo_on_hand_date, 
    :cargo_ready_date, :carrier_id, :carrier_released_date, 
    :confirmed_on_board_origin_date, :consignee_id, :consignee, :consolidator_address_id, :consolidator_address, 
    :container_stuffing_address_id, :container_stuffing_address, :container_unloaded_date, 
    :country_export_id, :country_import_id, :country_origin_id,
    :country_export, :country_import, :country_origin,
    :customs_released_carrier_date, :delay_reason_codes, :delivered_date, 
    :departure_date, :departure_last_foreign_port_date, :description_of_goods, 
    :destination_port_id, :destination_port, :do_issued_at, :docs_received_date, 
    :empty_out_at_origin_date, :empty_return_date, :entry_port_id, 
    :est_arrival_port_date, :est_delivery_date, :est_departure_date, 
    :est_inland_port_date, :est_load_date, :eta_last_foreign_port_date, 
    :export_license_required, :fcr_created_final_date, :final_dest_port_id, 
    :first_port_receipt_id, :first_port_receipt, :fish_and_wildlife, :forwarder_id, :freight_terms, 
    :freight_total, :full_container_discharge_date, :full_ingate_date, 
    :full_out_gate_discharge_date, :gross_weight, :hazmat, 
    :house_bill_of_lading, :importer_id, :importer, :importer_reference, 
    :in_warehouse_time, :inland_destination_port_id, :inland_port_date, 
    :invoice_total, :isf_sent_at, :isf_sent_by_id, :lacey_act, :lading_port_id, :lading_port, 
    :last_exported_from_source, :last_file_bucket, :last_file_path, 
    :last_foreign_port_id, :lcl, :marks_and_numbers, :master_bill_of_lading, 
    :mode, :number_of_packages, :number_of_packages_uom, :on_rail_destination_date, 
    :packing_list_sent_by_id, :packing_list_sent_date, :pickup_at, 
    :port_last_free_day, :receipt_location, :reference, :requested_equipment, 
    :seller_address_id, :seller_address, :ship_from_id, :ship_from, :ship_to_address_id, :ship_to_address, :ship_to_id, 
    :shipment_cutoff_date, :shipment_instructions_sent_by_id, 
    :shipment_instructions_sent_date, :shipment_type, :solid_wood_packing_materials, 
    :trucker_name, :unlading_port_id, :unlading_port, :vendor_id, :vendor, :vessel, :vessel_carrier_scac, 
    :vessel_nationality, :vgm_sent_by_id, :vgm_sent_date, :volume, :voyage, 
    :warning_overridden_at, :warning_overridden_by_id
  
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
  belongs_to :packing_list_sent_by, class_name: "User"
  belongs_to :vgm_sent_by, class_name: "User"
  belongs_to :country_origin, class_name: "Country"
  belongs_to :country_export, class_name: "Country"
  belongs_to :country_import, class_name: "Country"
  belongs_to :warning_overridden_by, :class_name => "User"

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
  def can_request_booking? user
    OpenChain::Registries::OrderBookingRegistry.can_request_booking? self, user
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
    OpenChain::Registries::OrderBookingRegistry.request_booking_hook(self,user)
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
    self.booked_quantity = calculate_booked_quantity
    self.save!
    OpenChain::EventPublisher.publish :shipment_booking_confirm, self
    self.create_snapshot_with_async_option async_snapshot, user
  end

  def calculate_booked_quantity
    # The system used to use shipment lines to calculate the booked_quantity..this was before we added the booking_lines
    # Now, look for booking lines, if that's there then sum that amount...otherwise, fall back to summing the shipment lines

    lines = (self.booking_lines.length > 0) ? self.booking_lines : self.shipment_lines
    sum = BigDecimal("0")
    lines.each {|l| sum += l.quantity unless l.quantity.nil? }
    sum
  end
  private :calculate_booked_quantity

  def async_confirm_booking! user
    self.confirm_booking! user, true
  end

  def can_revise_booking? user
    OpenChain::Registries::OrderBookingRegistry.can_revise_booking? self, user
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
    OpenChain::Registries::OrderBookingRegistry.revise_booking_hook(self, user)
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
    OpenChain::Registries::ShipmentRegistry.can_cancel?(self, user)
  end
  def cancel_shipment! user, async_snapshot: false, canceled_date: Time.zone.now, snapshot_context: nil
    Shipment.transaction do
      self.canceled_date = canceled_date
      self.canceled_by = user
      OpenChain::Registries::ShipmentRegistry.cancel_shipment_hook(self, user)
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
    self.create_snapshot_with_async_option async_snapshot, user, nil, snapshot_context
  end

  def async_cancel_shipment! user
    self.cancel_shipment! user, async_snapshot: true
  end
  def can_uncancel? user
    OpenChain::Registries::ShipmentRegistry.can_uncancel?(self, user)
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
    self.cancel_requested_at = Time.zone.now
    self.cancel_requested_by = user
    self.save!
    OpenChain::EventPublisher.publish :shipment_cancel_request, self
    self.create_snapshot_with_async_option async_snapshot, user
    OpenChain::Registries::OrderBookingRegistry.post_request_cancel_hook(self, user)
    nil
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

  # This method is here to just provide API consistency across module for determining if something is closed/cancel'ed
  def closed?
    !self.canceled_date.nil?
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
    !(self.mode.to_s =~ /OCEAN/i).nil?
  end

  def air?
    !(self.mode.to_s =~ /AIR/i).nil?
  end

  def normalized_booking_mode
    # strip hyphenated additions
    /\w+(?=\W)*/.match(booking_mode).try(:[], 0).try(:upcase) if booking_mode.present?
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
    OpenChain::Registries::OrderBookingRegistry.can_edit_booking? self, user
  end

  # can the user currently add lines to this shipment
  def can_add_remove_shipment_lines?(user)
    return self.can_edit?(user)
  end

  def can_add_remove_booking_lines?(user)
    # At any point up till there are actual manifest/shipment lines users w/ edit ability
    # can remove booking lines.
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
    (self.volume / BigDecimal("0.006")).round(2) if self.volume
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

  # Requested Equipment is a text field that contains (potentially) multiple pairs of quantity and container type
  # (e.g. "3 40HC").  If multiple container types are involved, they'll be split into multiple lines.  This method is a
  # helper for dealing with the field, since it's fairly awkward.  It returns an array of 2-value arrays, each
  # containing the quantity and type for the pair.  An empty array returned if the field is blank.  An exception is
  # thrown if any of the lines do not fit the expected pattern.  Blank lines are removed from the output.
  def get_requested_equipment_pieces
    pieces = []
    if self.requested_equipment.present?
      pieces = self.requested_equipment.lines.collect do |ln|
        ln.strip!
        components = ln.split(' ')
        case components.size
          when 0
            nil
          when 2
            components
          else
            raise "Bad requested equipment field, expected each line to have number and type like \"3 40HC\", got #{self.requested_equipment}."
        end
      end
    end
    pieces.compact!
    pieces
  end
end
