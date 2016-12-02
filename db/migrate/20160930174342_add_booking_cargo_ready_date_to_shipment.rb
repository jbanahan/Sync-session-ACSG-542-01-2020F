class AddBookingCargoReadyDateToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :booking_cargo_ready_date, :date
    add_index :shipments, :booking_cargo_ready_date
  end
end
