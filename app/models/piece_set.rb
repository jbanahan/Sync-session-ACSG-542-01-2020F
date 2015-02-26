class PieceSet < ActiveRecord::Base
#PieceSets are used to link different modules together (like to mark the the items on a shipment are from a particular order)
  belongs_to :order_line
  belongs_to :sales_order_line
  belongs_to :shipment_line
  belongs_to :delivery_line
  belongs_to :milestone_plan
  belongs_to :commercial_invoice_line
  belongs_to :drawback_import_line
  belongs_to :security_filing_line

  has_one :milestone_forecast_set, :dependent=>:destroy, :autosave=>true

  validates :quantity, :presence => true
  validates_numericality_of :quantity, :greater_than_or_equal_to => 0
  validate :validate_product_integrity

  #merge all piece sets together that have the same linked keys and set the quantity to the sum of all records
  def self.merge_duplicates! base
    all = PieceSet.where(
      order_line_id:base.order_line_id,
      sales_order_line_id:base.sales_order_line_id,
      shipment_line_id:base.shipment_line_id,
      delivery_line_id:base.delivery_line_id,
      commercial_invoice_line_id:base.commercial_invoice_line_id,
      drawback_import_line_id:base.drawback_import_line_id,
      security_filing_line_id:base.security_filing_line_id
      )
    return if all.size < 2
    first = all.first
    PieceSet.transaction do
      all.each do |ps|
        next if ps == first
        first.quantity += ps.quantity
        destroyed = ps.destroy
        raise "Error destroying PieceSet with ID #{ps.id}" unless destroyed
      end
      first.save!
    end
  end

  #destroy this piece set if it only has one foriegn key
  def destroy_if_one_key
    keys = [:order_line_id,
      :sales_order_line_id,
      :shipment_line_id,
      :delivery_line_id,
      :commercial_invoice_line_id,
      :drawback_import_line_id,
      :security_filing_line_id,]
    key_count = keys.inject(0) {|i,m| i + (!self.attributes[m.to_s].blank? ? 1 : 0)}
    if key_count <= 1
      return self.destroy
    else
      return false
    end
  end

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

  def identifiers user = User.current
    r = {}
    ord_num_field = ModelField.find_by_uid(:ord_ord_num)
    r[:order] = {:label=>ord_num_field.label,:value=>ord_num_field.process_export(self.order_line.order, user)} if self.order_line && ord_num_field.can_view?(user)
    ship_ref_field = ModelField.find_by_uid(:shp_ref)
    r[:shipment] = {:label=>ship_ref_field.label,:value=>ship_ref_field.process_export(self.shipment_line.shipment, user)} if self.shipment_line && ship_ref_field.can_view?(user)
    sales_order_field = ModelField.find_by_uid(:sale_order_number)
    r[:sales_order] = {:label=>sales_order_field.label,:value=>sales_order_field.process_export(self.sales_order_line.sales_order, user)} if self.sales_order_line && sales_order_field.can_view?(user)
    deliver_field = ModelField.find_by_uid(:del_ref)
    r[:delivery] = {:label=>deliver_field.label,:value=>deliver_field.process_export(self.delivery_line.delivery, user)} if self.delivery_line && deliver_field.can_view?(user)
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
