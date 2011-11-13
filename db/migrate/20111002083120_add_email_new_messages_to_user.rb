class AddEmailNewMessagesToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :email_new_messages, :boolean, :default => false
  end

  def self.down
    remove_column :users, :email_new_messages
  end
end
