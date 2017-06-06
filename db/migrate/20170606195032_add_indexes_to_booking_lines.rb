class AddIndexesToBookingLines < ActiveRecord::Migration
  def change
    add_index :booking_lines, :shipment_id
    add_index :booking_lines, :product_id
    add_index :booking_lines, [:order_id, :order_line_id]
    add_index :booking_lines, :order_line_id
  end
end
