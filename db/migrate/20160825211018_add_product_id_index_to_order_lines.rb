class AddProductIdIndexToOrderLines < ActiveRecord::Migration
  def change
    add_index :order_lines, :product_id
  end
end
