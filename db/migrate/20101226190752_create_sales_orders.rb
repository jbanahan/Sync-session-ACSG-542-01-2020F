class CreateSalesOrders < ActiveRecord::Migration
  def self.up
    create_table :sales_orders do |t|
      t.string :order_number
      t.date :order_date
      t.integer :customer_id
      t.string :customer_order_number
      t.string :payment_terms
      t.string :ship_terms
      t.text :comments
      t.integer :division_id
      t.integer :ship_to_id
       

      t.timestamps
    end
  end

  def self.down
    drop_table :sales_orders
  end
end
