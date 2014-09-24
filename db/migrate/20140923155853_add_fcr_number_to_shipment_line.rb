class AddFcrNumberToShipmentLine < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :fcr_number, :string
    add_index :shipment_lines, :fcr_number
  end
end
