class AddFreightAttributesToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :master_bill_of_lading, :string
    add_column :shipments, :house_bill_of_lading, :string
    add_column :shipments, :booking_number, :string
    add_column :shipments, :receipt_location, :string
    add_column :shipments, :lading_port_id, :integer
    add_column :shipments, :unlading_port_id, :integer
    add_column :shipments, :entry_port_id, :integer
    add_column :shipments, :destination_port_id, :integer
    add_column :shipments, :freight_terms, :string
    add_column :shipments, :lcl, :boolean
    add_column :shipments, :shipment_type, :string #CFS/CY
    add_column :shipments, :booking_shipment_type, :string
    add_column :shipments, :booking_mode, :string
    add_column :shipments, :vessel, :string
    add_column :shipments, :voyage, :string
    add_column :shipments, :vessel_carrier_scac, :string
    add_column :shipments, :booking_received_date, :date
    add_column :shipments, :booking_confirmed_date, :date
    add_column :shipments, :booking_cutoff_date, :date
    add_column :shipments, :booking_est_arrival_date, :date
    add_column :shipments, :booking_est_departure_date, :date
    add_column :shipments, :docs_received_date, :date
    add_column :shipments, :cargo_on_hand_date, :date
    add_column :shipments, :est_departure_date, :date
    add_column :shipments, :departure_date, :date
    add_column :shipments, :est_arrival_port_date, :date
    add_column :shipments, :arrival_port_date, :date
    add_column :shipments, :est_delivery_date, :date
    add_column :shipments, :delivered_date, :date
  end
end
