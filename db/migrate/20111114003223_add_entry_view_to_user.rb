class AddEntryViewToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :entry_view, :boolean
  end

  def self.down
    remove_column :users, :entry_view
  end
end
