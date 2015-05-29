class AddBookingIntegrityFieldsToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :booking_carrier, :string
    add_column :shipments, :booking_vessel, :string
    add_column :shipments, :delay_reason_codes, :string
  end
end
