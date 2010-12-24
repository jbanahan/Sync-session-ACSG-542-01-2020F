class CreateItemChangeSubscriptions < ActiveRecord::Migration
  def self.up
    create_table :item_change_subscriptions do |t|
      t.integer :user_id
      t.integer :order_id
      t.integer :shipment_id
      t.integer :product_id
      t.boolean :app_message
      t.boolean :email

      t.timestamps
    end
  end

  def self.down
    drop_table :item_change_subscriptions
  end
end
