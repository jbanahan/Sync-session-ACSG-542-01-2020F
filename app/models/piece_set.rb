class PieceSet < ActiveRecord::Base
#PieceSets are used to link different modules together (like to mark the the items on a shipment are from a particular order)
    belongs_to :order_line
    belongs_to :inventory_in
    belongs_to :inventory_out
    belongs_to :sales_order_line
    belongs_to :shipment_line
    belongs_to :delivery_line

    validates :quantity, :presence => true
    validates_numericality_of :quantity, :greater_than_or_equal_to => 0
    validate :validate_product_integrity
  
  private
  def validate_product_integrity
    #all linked objects must have the same product
    base_product = nil
    [self.order_line,self.shipment_line,self.sales_order_line,self.delivery_line].each do |line|
      if !line.nil?
        if base_product.nil?
          base_product = line.product
        elsif !line.product.nil? && base_product!=line.product
          self.errors[:base] << "Data Integrity Error: Piece Set cannot be saved with multiple linked products."
          return false
        end
      end
    end
    return true
  end
end
