class CreateOrderLines < ActiveRecord::Migration
  def self.up
    create_table :order_lines do |t|
      t.references :product
      t.decimal :ordered_qty
			t.string  :unit_of_measure
      t.decimal :price_per_unit
      t.date :expected_ship_date
      t.date :expected_delivery_date
			t.date :ship_no_later_date
      t.references :order

      t.timestamps
    end
  end

  def self.down
    drop_table :order_lines
  end
end
