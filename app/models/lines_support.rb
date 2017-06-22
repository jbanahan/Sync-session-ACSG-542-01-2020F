module LinesSupport
  extend ActiveSupport::Concern
  include DefaultLineNumberSupport

  #need to implement two private methods in mixed in class "parent_obj" and "parent_id_where".  See OrderLine for example.
  included do
    has_many :piece_sets, autosave: true
    has_many :order_lines, :through => :piece_sets
    has_many :sales_order_lines, :through => :piece_sets
    has_many :shipment_lines, :through => :piece_sets
    has_many :delivery_lines, :through => :piece_sets
    has_many :drawback_import_lines, :through => :piece_sets
    has_many :commercial_invoice_lines, :through => :piece_sets
    has_many :security_filing_lines, :through=>:piece_sets

    unless ["CommercialInvoiceLine","SecurityFilingLine"].include?(self.name)
      belongs_to :product
      before_validation :default_quantity
      validates :product, :presence => true

      unless self.name == "DrawbackImportLine"
        before_validation :default_line_number
      end
    end

    attr_accessor :linked_order_line_id
    attr_accessor :linked_shipment_line_id
    attr_accessor :linked_sales_order_line_id
    attr_accessor :linked_delivery_line_id
    attr_accessor :linked_drawback_line_id
    attr_accessor :linked_commercial_invoice_line_id
    attr_accessor :linked_security_filing_line_id
    after_save :process_links
    after_destroy :merge_piece_sets
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
    :sales_order_line_id=>@linked_sales_order_line_id,:delivery_line_id=>@linked_delivery_line_id,
    :commercial_invoice_line_id=>@linked_commercial_invoice_line_id,:drawback_import_line_id=>@linked_drawback_line_id,
    :security_filing_line_id=>@linked_security_filing_line_id}.each do |s,i|
      process_link s,i
    end
  end

  #returns the worst milestone state of all associated piece sets
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

  #clean up piece sets after destroy
  def merge_piece_sets
    my_id = self.id
    self.piece_sets.each do |ps|
      ps.update_attributes(self.class.reflections[:piece_sets].foreign_key=>nil)
      PieceSet.merge_duplicates! ps
    end
  end

  def create_snapshot_with_async_option async, user=User.current, imported_file=nil
    parent_obj.create_snapshot_with_async_option async, user, imported_file
  end

  def create_snapshot user=User.current, imported_file=nil
    parent_obj.create_snapshot user, imported_file
  end

  def create_async_snapshot user=User.current, imported_file=nil
    parent_obj.create_async_snapshot user, imported_file
  end

  private
  def process_link field_symbol, id
    unless id.nil?
      ps = self.piece_sets.where(field_symbol=>id).first
      if ps.nil? #if there is a PieceSet only linked to the "linked line", it's a place holder that needs to have it's quantity reduced or be replaced
        holding_piece_set = PieceSet.where(field_symbol=>id).where("(ifnull(piece_sets.order_line_id,0)+ifnull(piece_sets.shipment_line_id,0)+ifnull(piece_sets.sales_order_line_id,0)+ifnull(piece_sets.delivery_line_id,0)+ifnull(piece_sets.drawback_import_line_id,0)+ifnull(piece_sets.commercial_invoice_line_id,0))=?",id).first
        if holding_piece_set
          if holding_piece_set.quantity <= self.quantity
            holding_piece_set.destroy
          else
            holding_piece_set.update_attributes(:quantity=>holding_piece_set.quantity-self.quantity)
          end
        end
      end
      ps = self.piece_sets.build(field_symbol=>id) if ps.nil?
      ps.quantity = self.quantity
      ps.save
      ps.errors.full_messages.each {|m| self.errors[:base]<<m}
    end
  end
end
