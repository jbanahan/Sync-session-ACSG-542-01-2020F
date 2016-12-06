class AddSystemUserToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :system_user, :boolean
    execute 'UPDATE users SET system_user=true WHERE username IN ("integration", "ApiAdmin")'
  end

  def self.down
    remove_column :users, :system_user
  end
end
