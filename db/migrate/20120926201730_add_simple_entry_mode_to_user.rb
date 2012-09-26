class AddSimpleEntryModeToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :simple_entry_mode, :boolean
  end

  def self.down
    remove_column :users, :simple_entry_mode
  end
end
