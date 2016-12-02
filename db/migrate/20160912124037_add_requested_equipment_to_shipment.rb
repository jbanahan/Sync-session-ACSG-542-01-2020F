class AddRequestedEquipmentToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :requested_equipment, :text
  end
end
