class AddDimensionalWeightsToShipment < ActiveRecord::Migration
  def up
    change_column :shipments, :gross_weight, :decimal, :precision => 9, :scale => 2
    add_column :shipments, :volume, :decimal, :precision => 9, :scale => 2
  end

  def down
    change_column :shipments, :gross_weight, :decimal
    remove_column :shipments, :volume
  end
end
