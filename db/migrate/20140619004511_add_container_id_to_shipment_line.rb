class AddContainerIdToShipmentLine < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :container_id, :integer
    add_index :shipment_lines, :container_id
  end
end
