class CreateSalesOrderLines < ActiveRecord::Migration
  def self.up
    create_table :sales_order_lines do |t|
      t.integer :product_id
      t.decimal :ordered_qty
      t.decimal :price_per_unit
      t.date :expected_ship_date
      t.date :expected_delivery_date
      t.date :ship_no_later_date
      t.integer :sales_order_id
      t.integer :line_number

      t.timestamps
    end
  end

  def self.down
    drop_table :sales_order_lines
  end
end
