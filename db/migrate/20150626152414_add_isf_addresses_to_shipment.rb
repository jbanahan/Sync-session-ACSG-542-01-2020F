class AddIsfAddressesToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :manufacturer_address_id, :integer
    add_column :shipments, :seller_address_id, :integer
    add_column :shipments, :buyer_address_id, :integer
    add_column :shipments, :ship_to_address_id, :integer
    add_column :shipments, :container_stuffing_address_id, :integer
    add_column :shipments, :consolidator_address_id, :integer
  end
end
