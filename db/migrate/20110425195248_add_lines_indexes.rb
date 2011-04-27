class AddLinesIndexes < ActiveRecord::Migration
  def self.up
    add_index :sales_order_lines, :sales_order_id
    add_index :order_lines, :order_id
    add_index :delivery_lines, :delivery_id
    add_index :shipment_lines, :shipment_id
  end

  def self.down
    remove_index :sales_order_lines, :sales_order_id
    remove_index :order_lines, :order_id
    remove_index :delivery_lines, :delivery_id
    remove_index :shipment_lines, :shipment_id
  end
end
