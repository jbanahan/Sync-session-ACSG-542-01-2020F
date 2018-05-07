# == Schema Information
#
# Table name: orders
#
#  accepted_at                  :datetime
#  accepted_by_id               :integer
#  agent_id                     :integer
#  approval_status              :string(255)
#  closed_at                    :datetime
#  closed_by_id                 :integer
#  created_at                   :datetime         not null
#  currency                     :string(255)
#  customer_order_number        :string(255)
#  customer_order_status        :string(255)
#  division_id                  :integer
#  factory_id                   :integer
#  first_expected_delivery_date :date
#  fob_point                    :string(255)
#  id                           :integer          not null, primary key
#  importer_id                  :integer
#  last_exported_from_source    :datetime
#  last_file_bucket             :string(255)
#  last_file_path               :string(255)
#  last_revised_date            :date
#  mode                         :string(255)
#  order_date                   :date
#  order_from_address_id        :integer
#  order_number                 :string(255)
#  processing_errors            :text
#  product_category             :string(255)
#  season                       :string(255)
#  ship_from_id                 :integer
#  ship_to_id                   :integer
#  ship_window_end              :date
#  ship_window_start            :date
#  terms_of_payment             :string(255)
#  terms_of_sale                :string(255)
#  tpp_survey_response_id       :integer
#  updated_at                   :datetime         not null
#  vendor_id                    :integer
#
# Indexes
#
#  index_orders_on_accepted_at                            (accepted_at)
#  index_orders_on_accepted_by_id                         (accepted_by_id)
#  index_orders_on_agent_id                               (agent_id)
#  index_orders_on_approval_status                        (approval_status)
#  index_orders_on_closed_at                              (closed_at)
#  index_orders_on_closed_by_id                           (closed_by_id)
#  index_orders_on_factory_id                             (factory_id)
#  index_orders_on_first_expected_delivery_date           (first_expected_delivery_date)
#  index_orders_on_fob_point                              (fob_point)
#  index_orders_on_importer_id_and_customer_order_number  (importer_id,customer_order_number)
#  index_orders_on_order_from_address_id                  (order_from_address_id)
#  index_orders_on_order_number                           (order_number)
#  index_orders_on_season                                 (season)
#  index_orders_on_ship_from_id                           (ship_from_id)
#  index_orders_on_ship_window_end                        (ship_window_end)
#  index_orders_on_ship_window_start                      (ship_window_start)
#  index_orders_on_tpp_survey_response_id                 (tpp_survey_response_id)
#

require 'open_chain/event_publisher'
require 'open_chain/registries/order_acceptance_registry'
require 'open_chain/registries/order_booking_registry'

class Order < ActiveRecord::Base
  include CoreObjectSupport
  include IntegrationParserSupport

  belongs_to :division
	belongs_to :vendor,  :class_name => "Company"
	belongs_to :ship_to, :class_name => "Address"
  belongs_to :ship_from, :class_name => "Address"
  belongs_to :order_from_address, :class_name => "Address"
  belongs_to :importer, :class_name => "Company"
  belongs_to :agent, :class_name=>"Company"
  belongs_to :closed_by, :class_name=>'User'
  belongs_to :factory, :class_name=>'Company'
  belongs_to :tpp_survey_response, :class_name=>'SurveyResponse'
  belongs_to :accepted_by, :class_name=>'User'
  belongs_to :selling_agent, :class_name=>'Company'

	validates :vendor, :presence => true, :unless => :has_importer?
  validates :importer, :presence => true, :unless => :has_vendor?

	has_many :order_lines, dependent: :destroy, order: 'line_number', autosave: true, inverse_of: :order
	has_many :piece_sets, :through => :order_lines
  has_many :booking_lines_by_order_line, :through => :order_lines, source: :booking_lines
  has_many :booking_lines

  accepts_nested_attributes_for :order_lines, :allow_destroy => true


  ########
  # Post Create Logic (must be called manually after an order is created in the system to trigger events & snapshots)
  ########
  def post_create_logic! user, async_snapshot = false
    OpenChain::EventPublisher.publish :order_create, self
    self.create_snapshot_with_async_option async_snapshot, user
  end

  def async_post_create_logic! user
    self.post_create_logic! user, true
  end

  ########
  # Post Update Logic (must be called manually after an order is update in the system to trigger events & snapshots).  This doesn't need to be called every time an order is updated, only when the update is relevant to the user community.
  ########
  def post_update_logic! user, async_snapshot = false
    OpenChain::EventPublisher.publish :order_update, self
    self.create_snapshot_with_async_option async_snapshot, user
  end

  def async_post_update_logic! user
    self.post_update_logic! user, true
  end


  ########
  # Order Acceptance Logic
  ########

  def accept! user, async_snapshot = false
    accept_logic(user)
    self.save!
    OpenChain::EventPublisher.publish :order_accept, self
    self.create_snapshot_with_async_option async_snapshot, user
  end

  def accept_logic user
    mark_order_as_accepted
    self.accepted_by = user
    self.accepted_at = Time.zone.now
  end

  def async_accept! user
    self.accept! user, true
  end

  def unaccept! user, async_snapshot = false
    unaccept_logic(user)
    self.save!
    OpenChain::EventPublisher.publish :order_unaccept, self
    self.create_snapshot_with_async_option async_snapshot, user
  end

  def unaccept_logic user
    self.approval_status = nil
    self.accepted_by = nil
    self.accepted_at = nil
  end

  def async_unaccept! user
    self.unaccept! user, true
  end

  # can the order be accepted (regardless of user permissions)
  def can_be_accepted?
    OpenChain::Registries::OrderAcceptanceRegistry.can_be_accepted? self
  end

  def can_accept? u
    OpenChain::Registries::OrderAcceptanceRegistry.can_accept?(self,u)
  end

  # Don't use this method directly unless you know there is no acceptance
  # policy for the given company and the orders need be selectable on the shipment screen.
  def mark_order_as_accepted
    self.approval_status = 'Accepted'
  end

  ########
  # Order Close Logic
  ########

  scope :not_closed, where('orders.closed_at is null')

  #set the order as closed and take a snapshot and save!
  def close! user, async_snapshot=false
    close_logic(user)
    self.save!
    OpenChain::EventPublisher.publish :order_close, self
    self.create_snapshot_with_async_option async_snapshot, user, nil
  end

  def close_logic user
    self.closed_by = user
    self.closed_at = Time.zone.now
    nil
  end

  #set the order as closed, save!, and take an snapshot in another thread
  def async_close! user
    self.close! user, true
  end
  def reopen! user, async_snapshot = false
    reopen_logic(user)
    self.save!
    OpenChain::EventPublisher.publish :order_reopen, self
    self.create_snapshot_with_async_option async_snapshot, user
  end

  def reopen_logic user
    self.closed_by = nil
    self.closed_at = nil
    nil
  end

  def async_reopen! user
    self.reopen! user, true
  end
  def closed?
    !self.closed_at.nil?
  end
  def can_close? user
    user.edit_orders? && (user.company == self.importer || user.company.master?)
  end

  #######
  # Order Booking Logic
  #######
  def can_book? user
    OpenChain::Registries::OrderBookingRegistry.can_book?(self, user)
  end

  def associate_vendor_and_products! user
    return unless self.vendor
    return if self.order_lines.empty?

    already_assigned = self.vendor.products_as_vendor.pluck(:product_id)
    products_on_order = Set.new(self.order_lines.collect {|ol| ol.product_id}.compact).to_a

    needs_assignment = products_on_order - already_assigned

    needs_assignment.each do |product_id|
      self.vendor.product_vendor_assignments.create!(product_id:product_id).create_snapshot(user)
    end
  end

  #get Enumerable of agents that are shared between the vendor and importer
  def available_agents
    vendor_agents = []
    importer_agents = []
    if self.vendor
       vendor_agents = self.vendor.linked_companies.agents.to_a
    end
    if self.importer
      importer_agents = self.importer.linked_companies.agents.to_a
    end
    vendor_agents & importer_agents
  end

  def available_tpp_survey_responses
    return [] unless self.vendor
    ship_to_country_ids = self.order_lines.collect {|ol| ol.ship_to ? ol.ship_to.country_id : nil}.uniq.compact
    return SurveyResponse.
      not_expired.
      joins(:survey=>:trade_preference_program).
      where('survey_responses.user_id IN (SELECT id FROM users WHERE users.company_id = ?)',self.vendor_id).
      where('trade_preference_programs.destination_country_id IN (?)',ship_to_country_ids).
      where('survey_responses.submitted_date IS NOT NULL')
  end

	def related_shipments
	  r = Set.new
	  self.order_lines.each do |line|
	    r = r + line.related_shipments
	  end
	  return r
	end

  def related_bookings
    r = Set.new
    self.booking_lines.each { |line| r.add line.shipment }
    return r
  end

  # useful order number to show to user
  def display_order_number
    return self.customer_order_number unless self.customer_order_number.blank?
    return self.order_number
  end

  # Returns true if order appears on any shipments.
  def shipping?
    self.piece_sets.where("shipment_line_id is not null").count > 0
  end

  def booked?
    self.booking_lines.count > 0
  end

  def booked_qty
    v = self.booking_lines.sum(:quantity)
    v.nil? ? BigDecimal("0") : v
  end

	def can_view?(user)
	  return user.view_orders? &&
      (
        user.company.master ||
        (user.company_id == self.vendor_id) ||
        (user.company_id == self.importer_id) ||
        (user.company_id == self.agent_id) ||
        (user.company_id == self.factory_id) ||
        (user.company_id == self.selling_agent_id) ||
        user.company.linked_companies.include?(importer) ||
        user.company.linked_companies.include?(vendor) ||
        user.company.linked_companies.include?(selling_agent)
      )
	end

  def can_view_business_validation_results? u
    self.can_view?(u) && u.view_business_validation_results?
  end

  def self.search_where user
    return "1=1" if user.company.master?
    cid = user.company_id
    lstr = "(SELECT child_id FROM linked_companies WHERE parent_id = #{cid})"
    "(orders.vendor_id = #{cid} OR orders.vendor_id IN #{lstr} OR orders.importer_id = #{cid} OR orders.importer_id IN #{lstr} OR orders.factory_id = #{cid} OR orders.selling_agent_id = #{cid} OR orders.agent_id = #{cid})"
  end

  def can_edit?(user)
    return user.edit_orders? && self.can_view?(user)
  end

  def can_comment? user
    return user.comment_orders? && self.can_view?(user)
  end

  def can_attach? user
    return user.attach_orders? && self.can_view?(user)
  end

  def self.find_by_vendor(vendor)
    return Order.where({:vendor_id => vendor})
  end

  def find_same
    found = self.order_number.nil? ? [] : Order.where({:order_number => self.order_number.to_s})
    raise "Found multiple orders with the same order number #{self.order_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end

  def locked?
    !self.vendor.nil? && self.vendor.locked?
  end

  dont_shallow_merge :Order, ['id','created_at','updated_at','order_number']

  def shipped_qty
    q = 0
    self.order_lines.each do |line|
      q = q + line.shipped_qty
    end
    return q
  end

  def ordered_qty
    #optimize with a single query
    q = 0
    self.order_lines.each do |line|
      q = q + line.quantity
    end
    return q
  end

  def self.search_secure user, base_object
    base_object.where search_where user
  end


  def worst_milestone_state
    return nil if self.piece_sets.blank?
    highest_index = nil
    self.piece_sets.each do |p|
      ms = p.milestone_state
      if ms
        ms_index = MilestoneForecast::ORDERED_STATES.index(ms)
        if highest_index.nil?
          highest_index = ms_index
        elsif !ms_index.nil? && ms_index > highest_index
          highest_index = ms_index
        end
      end
    end
    highest_index.nil? ? nil : MilestoneForecast::ORDERED_STATES[highest_index]
  end

  # Generates a unique PO Number based on the vendor or importer information associated with the PO.  Importer/Vendor and Customer Order Number must
  # be set prior to calling this method.
  def create_unique_po_number order_number = self.customer_order_number
    # Use the importer/vendor identifier as the "uniqueness" factor on the order number.  This is only a factor for PO's utilized on a shared instance.
    uniqueness = nil
    if has_importer?
      uniqueness = self.importer.system_code.blank? ? (self.importer.alliance_customer_number.blank? ? self.importer.fenix_customer_number : self.importer.alliance_customer_number) : self.importer.system_code
      raise "Failed to create unique Order Number from #{self.customer_order_number} for Importer #{self.importer.name}." if uniqueness.blank?
    else
      uniqueness = self.vendor.system_code

      raise "Failed to create unique Order Number from #{self.customer_order_number} for Vendor #{self.vendor.name}." if uniqueness.blank?
    end

    Order.compose_po_number uniqueness, order_number
  end

  def self.compose_po_number company_identifer, order_number
    "#{company_identifer}-#{order_number}"
  end

  def add_processing_error message
    if self.processing_errors
      self.processing_errors + "\n " + message
    else
      self.processing_errors = message
    end
  end

  private
    def has_importer?
      self.importer.present?
    end

    def has_vendor?
      self.vendor.present?
    end
end
