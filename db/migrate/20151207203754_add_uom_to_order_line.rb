class AddUomToOrderLine < ActiveRecord::Migration
  def change
    add_column :order_lines, :unit_of_measure, :string
  end
end
