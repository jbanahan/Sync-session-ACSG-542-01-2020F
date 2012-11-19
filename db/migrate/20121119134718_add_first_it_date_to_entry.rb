class AddFirstItDateToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :first_it_date, :date
  end

  def self.down
    remove_column :entries, :first_it_date
  end
end
