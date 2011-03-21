class AddFKsForDeliveryAndShipmentLines < ActiveRecord::Migration
  def self.up
    add_column :shipment_lines, :shipment_id, :integer
    add_column :delivery_lines, :delivery_id, :integer
  end

  def self.down
    remove_column :delivery_lines, :delivery_id
    remove_column :shipment_lines, :shipment_id
  end
end
