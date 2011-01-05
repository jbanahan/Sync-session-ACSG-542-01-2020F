class PieceSet < ActiveRecord::Base
    belongs_to :order_line
    belongs_to :shipment
    belongs_to :product
    belongs_to :inventory_in
    belongs_to :inventory_out
    belongs_to :delivery
    belongs_to :sales_order_line

    validates :product,	:presence => true
    validates :quantity, :presence => true
    validates_numericality_of :quantity, :greater_than => 0
    validate :validate_unique_keys
    
    def find_same
      PieceSet.where(
        :product_id => self.product_id, 
        :order_line_id => self.order_line_id,
        :shipment_id => self.shipment_id,
        :inventory_in_id => self.inventory_in_id,
        :inventory_out_id => self.inventory_out_id,
        :adjustment_type => self.adjustment_type,
        :delivery_id => self.delivery_id,
        :sales_order_line_id => self.sales_order_line_id
      ).first      
    end
    
    def locked?
      (!self.product.nil? && self.product.locked?) ||
      (!self.shipment.nil? && self.shipment.locked?)
    end
    
    private 
    def validate_unique_keys
      same = find_same
      unless find_same.nil? || same.id == self.id
        self.errors[:base] << "PieceSet with these keys already exists. (Product: #{self.product_id}, OrderLine: #{self.order_line_id}, Shipment: #{self.shipment_id}, Inventory In: #{self.inventory_in_id}, SalesOrderLine: #{self.sales_order_line_id}, Delivery: #{self.delivery_id}, Inventory Out: #{self.inventory_out_id}, Adjustment: #{self.adjustment_type})"
      end
    end
    
end
