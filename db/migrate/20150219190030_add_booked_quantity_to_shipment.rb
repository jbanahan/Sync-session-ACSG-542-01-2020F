class AddBookedQuantityToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :booked_quantity, :decimal, precision: 11, scale: 2
  end
end
