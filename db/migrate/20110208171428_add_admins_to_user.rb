class AddAdminsToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :admin, :boolean
    add_column :users, :sys_admin, :boolean
  end

  def self.down
    remove_column :users, :sys_admin
    remove_column :users, :admin
  end
end
