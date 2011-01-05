class AddSalesOrderLineIdToPieceSet < ActiveRecord::Migration
  def self.up
    add_column :piece_sets, :sales_order_line_id, :integer
  end

  def self.down
    remove_column :piece_sets, :sales_order_line_id
  end
end
