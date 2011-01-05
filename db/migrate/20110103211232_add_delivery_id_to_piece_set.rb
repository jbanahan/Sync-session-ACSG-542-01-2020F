class AddDeliveryIdToPieceSet < ActiveRecord::Migration
  def self.up
    add_column :piece_sets, :delivery_id, :integer
  end

  def self.down
    remove_column :piece_sets, :delivery_id
  end
end
