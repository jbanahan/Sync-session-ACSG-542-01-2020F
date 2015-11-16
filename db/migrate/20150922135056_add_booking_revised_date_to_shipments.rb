class AddBookingRevisedDateToShipments < ActiveRecord::Migration
  def change
    add_column :shipments, :booking_revised_date, :date
  end
end
