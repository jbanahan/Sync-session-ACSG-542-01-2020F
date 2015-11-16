class MoveMfgAddressFromShipmentToLine < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :manufacturer_address_id, :integer
    remove_column :shipments, :manufacturer_address_id
  end
end
