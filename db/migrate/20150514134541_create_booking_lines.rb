class CreateBookingLines < ActiveRecord::Migration
  def change
    create_table :booking_lines do |t|
      t.integer :order_id
      t.integer :order_line_id
      t.integer :product_id
      t.decimal :quantity

      t.timestamps
    end
  end
end
