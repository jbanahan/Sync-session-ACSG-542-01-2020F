class AddQuantityToPieceSets < ActiveRecord::Migration
  def self.up
    add_column :piece_sets, :quantity, :decimal
  end

  def self.down
    remove_column :piece_sets, :quantity
  end
end
