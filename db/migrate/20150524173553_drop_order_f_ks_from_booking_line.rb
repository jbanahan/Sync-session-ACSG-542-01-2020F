class DropOrderFKsFromBookingLine < ActiveRecord::Migration
  def up
    remove_columns :booking_lines, :order_id, :order_line_id
  end

  def down
    add_column :booking_lines, :order_id, :integer
    add_column :booking_lines, :order_line_id, :integer
  end
end
