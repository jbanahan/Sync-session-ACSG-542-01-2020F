class AddLastPasswordChangeAndFailedLoginsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :password_changed_at, :datetime
    add_column :users, :failed_logins, :integer, default: 0
  end
end
