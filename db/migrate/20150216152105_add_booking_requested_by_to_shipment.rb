class AddBookingRequestedByToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :booking_requested_by_id, :integer
    add_index :shipments, :booking_requested_by_id
  end
end
