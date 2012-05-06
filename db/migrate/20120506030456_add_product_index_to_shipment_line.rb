class AddProductIndexToShipmentLine < ActiveRecord::Migration
  def self.up
    add_index :shipment_lines, :product_id
  end

  def self.down
    remove_index :shipment_lines, :product_id
  end
end
