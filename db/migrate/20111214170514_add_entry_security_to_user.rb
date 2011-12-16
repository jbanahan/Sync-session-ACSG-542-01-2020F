class AddEntrySecurityToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :entry_comment, :boolean
    add_column :users, :entry_attach, :boolean
    add_column :users, :entry_edit, :boolean
  end

  def self.down
    remove_column :users, :entry_edit
    remove_column :users, :entry_attach
    remove_column :users, :entry_comment
  end
end
