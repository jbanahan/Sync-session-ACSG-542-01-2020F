class AddSearchOpenToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :search_open, :boolean
  end

  def self.down
    remove_column :users, :search_open
  end
end
