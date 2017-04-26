class AddPasswordLockedToUsers < ActiveRecord::Migration
  def change
    add_column :users, :password_locked, :boolean, default: false
  end
end
