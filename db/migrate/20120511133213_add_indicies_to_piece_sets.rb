class AddIndiciesToPieceSets < ActiveRecord::Migration
  def self.up
    add_index :piece_sets, :shipment_line_id
    add_index :piece_sets, :order_line_id
  end

  def self.down
    remove_index :piece_sets, :shipment_line_id
    remove_index :piece_sets, :order_line_id
  end
end
