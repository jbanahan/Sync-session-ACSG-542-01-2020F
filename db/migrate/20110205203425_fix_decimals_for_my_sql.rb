class FixDecimalsForMySql < ActiveRecord::Migration
  def self.up
    change_column :custom_values, :decimal_value, :decimal, :precision => 13, :scale => 4
    change_column :piece_sets, :quantity, :decimal, :precision => 13, :scale => 4
    change_column :sales_order_lines, :ordered_qty, :decimal, :precision => 13, :scale => 4
    change_column :sales_order_lines, :price_per_unit, :decimal, :precision => 13, :scale => 4
    change_column :order_lines, :ordered_qty, :decimal, :precision => 13, :scale => 4
    change_column :order_lines, :price_per_unit, :decimal, :precision => 13, :scale => 4
  end

  def self.down
  end
end
