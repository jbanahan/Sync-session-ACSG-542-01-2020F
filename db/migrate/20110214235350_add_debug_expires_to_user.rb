class AddDebugExpiresToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :debug_expires, :datetime
  end

  def self.down
    remove_column :users, :debug_expires
  end
end
