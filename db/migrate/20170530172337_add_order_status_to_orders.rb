class AddOrderStatusToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :customer_order_status, :string
  end
end
