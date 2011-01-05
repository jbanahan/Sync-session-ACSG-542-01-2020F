class AddDeliveryIdItemChangeSubscription < ActiveRecord::Migration
  def self.up
    add_column :item_change_subscriptions, :delivery_id, :integer
  end

  def self.down
    remove_column :item_change_subscriptions, :delivery_id
  end
end
