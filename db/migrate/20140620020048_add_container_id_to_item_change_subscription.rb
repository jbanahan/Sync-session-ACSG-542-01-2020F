class AddContainerIdToItemChangeSubscription < ActiveRecord::Migration
  def change
    add_column :item_change_subscriptions, :container_id, :integer
    add_index :item_change_subscriptions, :container_id
  end
end
