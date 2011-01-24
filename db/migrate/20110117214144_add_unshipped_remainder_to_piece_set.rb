class AddUnshippedRemainderToPieceSet < ActiveRecord::Migration
  def self.up
    add_column :piece_sets, :unshipped_remainder, :boolean
  end

  def self.down
    remove_column :piece_sets, :unshipped_remainder
  end
end
