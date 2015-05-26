class AddWeightToBookingLines < ActiveRecord::Migration
  def change
    add_column :booking_lines, :gross_kgs, :decimal, precision: 9, scale: 2
    add_column :booking_lines, :cbms, :decimal, precision: 9, scale: 2
    add_column :booking_lines, :carton_qty, :integer
    add_column :booking_lines, :carton_set_id, :integer
  end
end
