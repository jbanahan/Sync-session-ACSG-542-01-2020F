class RemoveSalesOrderLineColumns < ActiveRecord::Migration
  def self.up
    remove_column :sales_order_lines, :expected_ship_date
    remove_column :sales_order_lines, :expected_delivery_date
    remove_column :sales_order_lines, :ship_no_later_date
  end

  def self.down
    add_column :sales_order_lines, :ship_no_later_date, :date
    add_column :sales_order_lines, :expected_delivery_date, :date
    add_column :sales_order_lines, :expected_ship_date, :date
  end
end
