class ReturnOrderKeysToBookingLine < ActiveRecord::Migration
  def up
    add_column :booking_lines, :order_id, :integer
    add_column :booking_lines, :order_line_id, :integer
  end

  def down
    remove_columns :booking_lines, :order_id, :order_line_id
  end
end
