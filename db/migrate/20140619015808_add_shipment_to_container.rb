class AddShipmentToContainer < ActiveRecord::Migration
  def change
    add_column :containers, :shipment_id, :integer
    add_index :containers, :shipment_id    
  end
end
