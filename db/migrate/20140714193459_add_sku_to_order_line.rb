class AddSkuToOrderLine < ActiveRecord::Migration
  def change
    add_column :order_lines, :sku, :string
    add_index :order_lines, :sku
  end
end
