module LinesSupport
#need to implement two private methods in mixed in class "parent_obj" and "parent_id_where".  See OrderLine for example.
  def self.included(base)
    base.instance_eval("belongs_to :product")
    base.instance_eval("has_many :piece_sets, :dependent => :destroy")
    base.instance_eval("has_many :order_lines, :through => :piece_sets")
    base.instance_eval("has_many :sales_order_lines, :through => :piece_sets")
    base.instance_eval("has_many :shipment_lines, :through => :piece_sets")
    base.instance_eval("has_many :delivery_lines, :through => :piece_sets")
    base.instance_eval("before_validation :default_line_number")
    base.instance_eval("before_validation :default_quantity")
    base.instance_eval("validates :product, :presence => true")
#the writers below are used to indicate that a related piece set should be created on save
    base.instance_eval("attr_accessor :linked_order_line_id")
    base.instance_eval("attr_accessor :linked_shipment_line_id")
    base.instance_eval("attr_accessor :linked_sales_order_line_id")
    base.instance_eval("attr_accessor :linked_delivery_line_id")
    base.instance_eval("after_save :process_links")
  end

  def default_line_number
    if self.line_number.nil? || self.line_number < 1
      max = nil
      max = self.class.where(parent_id_where).maximum(:line_number) unless parent_obj.nil?
      self.line_number = (max.nil? || max < 1) ? 1 : (max + 1)
    end
  end 

  def default_quantity
    self.quantity = 0 if self.quantity.nil?
  end

  def locked?
    !parent_obj.nil? && parent_obj.locked?
  end

  def can_edit? user
    parent_obj.can_edit? user
  end

  def can_view? user
    parent_obj.can_view? user
  end

  def process_links
    {:order_line_id=>@linked_order_line_id,:shipment_line_id=>@linked_shipment_line_id,
    :sales_order_line_id=>@linked_sales_order_line_id,:delivery_line_id=>@linked_delivery_line_id}.each do |s,i|
      process_link s,i
    end
  end

  private
  def process_link field_symbol, id
    unless id.nil?
      ps = self.piece_sets.where(field_symbol=>id).first
      ps = self.piece_sets.build(field_symbol=>id) if ps.nil?
      ps.quantity = self.quantity
      ps.save
      ps.errors.full_messages.each {|m| self.errors[:base]<<m}
    end
  end
end
