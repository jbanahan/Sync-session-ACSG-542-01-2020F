class Order < ActiveRecord::Base
  include CoreObjectSupport
  include IntegrationParserSupport

  belongs_to :division
	belongs_to :vendor,  :class_name => "Company"
	belongs_to :ship_to, :class_name => "Address"
  belongs_to :importer, :class_name => "Company"
	
	validates  :vendor, :presence => true, :unless => :has_importer?
  validates :importer, :presence => true, :unless => :has_vendor?
	
	has_many	 :order_lines, :dependent => :destroy, :order => 'line_number', :autosave => true
	has_many   :piece_sets, :through => :order_lines

	def related_shipments
	  r = Set.new
	  self.order_lines.each do |line|
	    r = r + line.related_shipments
	  end
	  return r
	end
	
	def can_view?(user)
	  return user.view_orders? && (user.company.master || (user.company_id == self.vendor_id) || (user.company_id == self.importer_id) ||
        user.company.linked_companies.include?(importer) || user.company.linked_companies.include?(vendor))
	end
	
  def self.search_where user
    return "1=1" if user.company.master?
    cid = user.company_id
    lstr = "(SELECT child_id FROM linked_companies WHERE parent_id = #{cid})"
    "(orders.vendor_id = #{cid} OR orders.vendor_id IN #{lstr} OR orders.importer_id = #{cid} OR orders.importer_id IN #{lstr})"
  end

  def can_edit?(user)
    return user.edit_orders?
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
  def create_unique_po_number
    # Use the importer/vendor identifier as the "uniqueness" factor on the order number.  This is only a factor for PO's utilized on a shared instance.
    uniqueness = nil
    if has_importer?
      uniqueness = self.importer.system_code.blank? ? (self.importer.alliance_customer_number.blank? ? self.importer.fenix_customer_number : self.importer.alliance_customer_number) : self.importer.system_code
      raise "Failed to create unique Order Number from #{self.customer_order_number} for Importer #{self.importer.name}." if uniqueness.blank?
    else
      uniqueness = self.vendor.system_code

      raise "Failed to create unique Order Number from #{self.customer_order_number} for Vendor #{self.vendor.name}." if uniqueness.blank?
    end

    "#{uniqueness}-#{self.customer_order_number}"
  end

  private 
    def has_importer?
      self.importer.present?
    end

    def has_vendor?
      self.vendor.present?
    end
end
