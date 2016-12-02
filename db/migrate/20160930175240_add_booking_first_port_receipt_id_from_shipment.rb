class AddBookingFirstPortReceiptIdFromShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :booking_first_port_receipt_id, :integer
  end
end
