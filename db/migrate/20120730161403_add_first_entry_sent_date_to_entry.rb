class AddFirstEntrySentDateToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :first_entry_sent_date, :datetime
  end

  def self.down
    remove_column :entries, :first_entry_sent_date
  end
end
