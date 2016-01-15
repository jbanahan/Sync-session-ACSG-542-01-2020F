class AddTotalCostDigitsToOrderLine < ActiveRecord::Migration
  def change
    add_column :order_lines, :total_cost_digits, :integer
  end
end
