class AddInventoryInIdToPieceSet < ActiveRecord::Migration
  def self.up
    add_column :piece_sets, :inventory_in_id, :integer
  end

  def self.down
    remove_column :piece_sets, :inventory_in_id
  end
end
