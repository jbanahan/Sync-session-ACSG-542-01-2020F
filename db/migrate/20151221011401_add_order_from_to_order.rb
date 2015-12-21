class AddOrderFromToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :order_from_address_id, :integer
    add_index :orders, :order_from_address_id
  end
end
