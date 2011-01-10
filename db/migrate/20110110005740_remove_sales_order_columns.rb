class RemoveSalesOrderColumns < ActiveRecord::Migration
  def self.up
    remove_column :sales_orders, :customer_order_number
    remove_column :sales_orders, :payment_terms
    remove_column :sales_orders, :ship_terms
  end

  def self.down
    add_column :sales_orders, :ship_terms, :string
    add_column :sales_orders, :payment_terms, :string
    add_column :sales_orders, :customer_order_number, :string
  end
end
