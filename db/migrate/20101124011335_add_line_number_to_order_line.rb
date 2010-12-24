class AddLineNumberToOrderLine < ActiveRecord::Migration
  def self.up
    add_column :order_lines, :line_number, :integer
  end

  def self.down
    remove_column :order_lines, :line_number
  end
end
