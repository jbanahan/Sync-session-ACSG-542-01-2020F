class AddTosAcceptToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :tos_accept, :datetime
  end

  def self.down
    remove_column :users, :tos_accept
  end
end
