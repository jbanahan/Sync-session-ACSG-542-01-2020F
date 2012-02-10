class AddFileLoggedDateToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :file_logged_date, :datetime
  end

  def self.down
    remove_column :entries, :file_logged_date
  end
end
