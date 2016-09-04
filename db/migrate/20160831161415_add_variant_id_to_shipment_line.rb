class AddVariantIdToShipmentLine < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :variant_id, :integer
    add_index :shipment_lines, :variant_id
  end
end
