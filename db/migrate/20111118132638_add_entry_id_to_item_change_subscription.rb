class AddEntryIdToItemChangeSubscription < ActiveRecord::Migration
  def self.up
    add_column :item_change_subscriptions, :entry_id, :integer
  end

  def self.down
    remove_column :item_change_subscriptions, :entry_id
  end
end
