class AddAdjustmentTypeToPieceSet < ActiveRecord::Migration
  def self.up
    add_column :piece_sets, :adjustment_type, :string
  end

  def self.down
    remove_column :piece_sets, :adjustment_type
  end
end
