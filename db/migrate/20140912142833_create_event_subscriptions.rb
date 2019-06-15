class CreateEventSubscriptions < ActiveRecord::Migration
  def change
    create_table :event_subscriptions do |t|
      t.references :user
      t.string :event_type
      t.boolean :email

      t.timestamps null: false
    end
    add_index :event_subscriptions, :user_id
  end
end
