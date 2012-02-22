class PieceSet < ActiveRecord::Base
#PieceSets are used to link different modules together (like to mark the the items on a shipment are from a particular order)
    belongs_to :order_line
    belongs_to :sales_order_line
    belongs_to :shipment_line
    belongs_to :delivery_line
    belongs_to :milestone_plan
    belongs_to :commercial_invoice_line
    belongs_to :drawback_import_line

    has_one :milestone_forecast_set, :dependent=>:destroy, :autosave=>true

    validates :quantity, :presence => true
    validates_numericality_of :quantity, :greater_than_or_equal_to => 0
    validate :validate_product_integrity
  
  def change_milestone_plan? user
    return false if order_line && !order_line.order.can_edit?(user)
    return false if shipment_line && !shipment_line.shipment.can_edit?(user)
    return false if sales_order_line && !sales_order_line.sales_order.can_edit?(user)
    return false if delivery_line && !delivery_line.delivery.can_edit?(user)
    return true
  end
  def create_forecasts
    self.build_forecasts
    self.milestone_forecast_set.save! unless self.milestone_forecast_set.nil?
    self.milestone_forecast_set
  end
  def build_forecasts
    self.milestone_plan.build_forecasts self unless self.milestone_plan.blank?
    self.milestone_forecast_set
  end

  def milestone_state
    self.milestone_forecast_set.blank? ? nil : self.milestone_forecast_set.state
  end

  def identifiers
    r = {}
    r[:order] = {:label=>ModelField.find_by_uid(:ord_ord_num).label,:value=>self.order_line.order.order_number} if self.order_line
    r[:shipment] = {:label=>ModelField.find_by_uid(:shp_ref).label,:value=>self.shipment_line.shipment.reference} if self.shipment_line
    r[:sales_order] = {:label=>ModelField.find_by_uid(:sale_order_number).label,:value=>self.sales_order_line.sales_order.order_number} if self.sales_order_line
    r[:delivery] = {:label=>ModelField.find_by_uid(:del_ref).label,:value=>self.delivery_line.delivery.reference} if self.delivery_line
    r
  end

  private
  def validate_product_integrity
    #all linked objects must have the same product
    base_product = nil
    [self.order_line,self.shipment_line,self.sales_order_line,self.delivery_line,self.drawback_import_line].each do |line|
      if !line.nil?
        if base_product.nil?
          base_product = line.product_id
        elsif !line.product_id.nil? && base_product!=line.product_id
          self.errors[:base] << "Data Integrity Error: Piece Set cannot be saved with multiple linked products."
          return false
        end
      end
    end
    return true
  end
end
