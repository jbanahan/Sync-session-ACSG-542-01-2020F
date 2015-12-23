class AddSystemMessageToEventSubscription < ActiveRecord::Migration
  def change
    add_column :event_subscriptions, :system_message, :boolean
  end
end
