class AddEntryIdToHistory < ActiveRecord::Migration
  def self.up
    add_column :histories, :entry_id, :integer
  end

  def self.down
    remove_column :histories, :entry_id
  end
end
