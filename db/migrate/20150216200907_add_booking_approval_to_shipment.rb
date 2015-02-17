class AddBookingApprovalToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :booking_approved_date, :date
    add_column :shipments, :booking_approved_by_id, :integer
    add_index :shipments, :booking_approved_by_id
  end
end
