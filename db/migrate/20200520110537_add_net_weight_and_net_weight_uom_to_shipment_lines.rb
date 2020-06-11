class AddNetWeightAndNetWeightUomToShipmentLines < ActiveRecord::Migration
  def change
    change_table(:shipment_lines, bulk: true) do |t|
      t.column :net_weight, :decimal, precision: 11, scale: 2
      t.column :net_weight_uom, :string
    end
  end
end
