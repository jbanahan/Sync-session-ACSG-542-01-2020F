class AddMeasurementsToShipmentLine < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :gross_kgs, :decimal, :precision => 9, :scale => 2
    add_column :shipment_lines, :cbms, :decimal, :precision => 9, :scale => 2
    add_column :shipment_lines, :carton_qty, :integer
  end
end
