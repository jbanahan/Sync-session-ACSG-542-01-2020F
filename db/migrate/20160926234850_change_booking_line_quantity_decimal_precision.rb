class ChangeBookingLineQuantityDecimalPrecision < ActiveRecord::Migration
  def up
    execute 'ALTER TABLE booking_lines MODIFY COLUMN quantity decimal(13,4)'
  end

  def down
  end
end
