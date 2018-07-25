class AddActiveDaysToUsers < ActiveRecord::Migration
  def up
    add_column :users, :active_days, :integer, default: 0

    execute "UPDATE users SET active_days = 1 WHERE last_request_at IS NOT NULL"
  end

  def down
    remove_column :users, :active_days
  end
end
