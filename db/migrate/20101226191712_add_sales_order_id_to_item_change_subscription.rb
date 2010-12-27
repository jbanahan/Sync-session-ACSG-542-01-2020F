class AddSalesOrderIdToItemChangeSubscription < ActiveRecord::Migration
  def self.up
    add_column :item_change_subscriptions, :sales_order_id, :integer
  end

  def self.down
    remove_column :item_change_subscriptions, :sales_order_id
  end
end
