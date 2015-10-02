class AddBookingRevisedByIdToShipments < ActiveRecord::Migration
  def change
    add_column :shipments, :booking_revised_by_id, :int
  end
end
