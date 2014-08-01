class AddQuickSearchIndicesToShipment < ActiveRecord::Migration
  def change
    add_index :shipments, :reference
    add_index :shipments, :master_bill_of_lading
    add_index :shipments, :booking_number
    add_index :shipments, :house_bill_of_lading
    add_index :shipments, :mode
    add_index :shipments, :est_arrival_port_date
    add_index :shipments, :est_departure_date
    add_index :shipments, :arrival_port_date
    add_index :shipments, :departure_date
  end
end
