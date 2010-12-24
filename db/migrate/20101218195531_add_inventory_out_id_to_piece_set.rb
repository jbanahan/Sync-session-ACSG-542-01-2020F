class AddInventoryOutIdToPieceSet < ActiveRecord::Migration
  def self.up
    add_column :piece_sets, :inventory_out_id, :integer
  end

  def self.down
    remove_column :piece_sets, :inventory_out_id
  end
end
