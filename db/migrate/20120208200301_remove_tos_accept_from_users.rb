class RemoveTosAcceptFromUsers < ActiveRecord::Migration
  def self.up
    remove_column :users, :tos_accept
  end

  def self.down
    add_column :users, :tos_accept, :datetime
  end
end
