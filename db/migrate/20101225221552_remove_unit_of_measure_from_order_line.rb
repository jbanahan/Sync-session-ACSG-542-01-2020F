class RemoveUnitOfMeasureFromOrderLine < ActiveRecord::Migration
  def self.up
    remove_column :order_lines, :unit_of_measure
  end

  def self.down
    add_column :order_lines, :unit_of_measure, :string
  end
end
