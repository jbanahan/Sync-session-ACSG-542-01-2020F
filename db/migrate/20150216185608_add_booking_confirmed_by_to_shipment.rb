class AddBookingConfirmedByToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :booking_confirmed_by_id, :integer
    add_index :shipments, :booking_confirmed_by_id
  end
end
