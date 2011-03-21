class AddProductIdForAllLines < ActiveRecord::Migration
  def self.up
    add_column :order_lines, :product_id, :integer
    add_column :shipment_lines, :product_id, :integer
    add_column :sales_order_lines, :product_id, :integer
    add_column :delivery_lines, :product_id, :integer
  end

  def self.down
    remove_column :delivery_lines, :product_id
    remove_column :sales_order_lines, :product_id
    remove_column :shipment_lines, :product_id
    remove_column :order_lines, :product_id
  end
end
