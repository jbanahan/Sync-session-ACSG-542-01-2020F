class AddHiddenMessagesToUser < ActiveRecord::Migration
  def change
    add_column :users, :hidden_message_json, :text
  end
end
