class AddFishAndWildlifeToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :fish_and_wildlife, :boolean
  end
end
