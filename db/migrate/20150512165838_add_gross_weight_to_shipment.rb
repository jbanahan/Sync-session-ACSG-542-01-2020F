class AddGrossWeightToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :gross_weight, :decimal
  end
end
