class AddDisallowPasswordToUser < ActiveRecord::Migration
  def change
    add_column :users, :disallow_password, :boolean
  end
end
