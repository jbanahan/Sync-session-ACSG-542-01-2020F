class SetUnlockedUsersToZeroFailedAttempts < ActiveRecord::Migration
  def up
    execute "UPDATE users SET failed_logins = 0 WHERE users.password_locked = false and users.failed_logins >= 5;"
  end

  def down; end
end
