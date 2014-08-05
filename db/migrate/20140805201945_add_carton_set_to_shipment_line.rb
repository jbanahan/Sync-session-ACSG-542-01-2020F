class AddCartonSetToShipmentLine < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :carton_set_id, :integer
    add_index :shipment_lines, :carton_set_id
  end
end
