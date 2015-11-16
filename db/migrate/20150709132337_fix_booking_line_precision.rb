class FixBookingLinePrecision < ActiveRecord::Migration
  def change
    change_column :booking_lines, :cbms, :decimal, precision:9, scale:5
  end
end
