class AddBookingRequestedEquipmentAndBookingTrackersToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :booking_requested_equipment, :string
    add_column :shipments, :booking_request_count, :integer
    add_index :shipments, :booking_request_count
  end
end
