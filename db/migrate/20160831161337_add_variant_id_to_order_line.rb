class AddVariantIdToOrderLine < ActiveRecord::Migration
  def change
    add_column :order_lines, :variant_id, :integer
    add_index :order_lines, :variant_id
  end
end
