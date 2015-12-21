class AddShipToToOrderLine < ActiveRecord::Migration
  def change
    add_column :order_lines, :ship_to_id, :integer
    add_index :order_lines, :ship_to_id
  end
end
