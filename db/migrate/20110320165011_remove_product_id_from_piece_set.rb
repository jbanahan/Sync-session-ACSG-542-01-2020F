class RemoveProductIdFromPieceSet < ActiveRecord::Migration
  def self.up
    remove_column :piece_sets, :product_id
  end

  def self.down
    add_column :piece_sets, :product_id, :integer
  end
end
