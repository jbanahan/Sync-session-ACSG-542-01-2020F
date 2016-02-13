require 'open_chain/event_publisher'
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

	validates  :vendor, :presence => true, :unless => :has_importer?
  validates :importer, :presence => true, :unless => :has_vendor?

	has_many	 :order_lines, dependent: :destroy, order: 'line_number', autosave: true, inverse_of: :order
	has_many   :piece_sets, :through => :order_lines

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
    mark_order_as_accepted
    self.save!
    OpenChain::EventPublisher.publish :order_accept, self
    self.create_snapshot_with_async_option async_snapshot, user
  end
  def async_accept! user
    self.accept! user, true
  end
  def unaccept! user, async_snapshot = false
    self.approval_status = nil
    self.save!
    OpenChain::EventPublisher.publish :order_unaccept, self
    self.create_snapshot_with_async_option async_snapshot, user
  end
  def async_unaccept! user
    self.unaccept! user, true
  end
  def can_accept? u
    u.admin? ||
    (
      (u.company == self.vendor || u.company == self.agent)  &&
      u.in_group?('ORDERACCEPT')
    )
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
    self.closed_by = user
    self.closed_at = Time.now
    self.save!
    OpenChain::EventPublisher.publish :order_close, self
    self.create_snapshot_with_async_option async_snapshot, user
  end
  #set the order as closed, save!, and take an snapshot in another thread
  def async_close! user
    self.close! user, true
  end
  def reopen! user, async_snapshot = false
    self.closed_by = self.closed_at = nil
    self.save!
    OpenChain::EventPublisher.publish :order_reopen, self
    self.create_snapshot_with_async_option async_snapshot, user
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

	def related_shipments
	  r = Set.new
	  self.order_lines.each do |line|
	    r = r + line.related_shipments
	  end
	  return r
	end

  # Returns true if order appears on any shipments.
  def shipping?
    self.piece_sets.where("shipment_line_id is not null").count > 0
  end

	def can_view?(user)
	  return user.view_orders? &&
      (
        user.company.master ||
        (user.company_id == self.vendor_id) ||
        (user.company_id == self.importer_id) ||
        (user.company_id == self.agent_id) ||
        (user.company_id == self.factory_id) ||
        user.company.linked_companies.include?(importer) ||
        user.company.linked_companies.include?(vendor)
      )
	end

  def can_view_business_validation_results? u
    self.can_view?(u) && u.view_business_validation_results?
  end

  def self.search_where user
    return "1=1" if user.company.master?
    cid = user.company_id
    lstr = "(SELECT child_id FROM linked_companies WHERE parent_id = #{cid})"
    "(orders.vendor_id = #{cid} OR orders.vendor_id IN #{lstr} OR orders.importer_id = #{cid} OR orders.importer_id IN #{lstr} OR orders.factory_id = #{cid})"
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

  private
    def has_importer?
      self.importer.present?
    end

    def has_vendor?
      self.vendor.present?
    end
end
