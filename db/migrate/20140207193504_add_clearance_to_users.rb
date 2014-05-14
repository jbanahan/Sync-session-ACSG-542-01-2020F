class AddClearanceToUsers < ActiveRecord::Migration
  def self.up
    change_table :users  do |t|
      t.string :encrypted_password, :limit => 128
      t.string :confirmation_token, :limit => 128
      t.string :remember_token, :limit => 128
    end

    add_index :users, :username
    add_index :users, :remember_token
    # Move users current password to column clearance expects it to be in (encrypted password, remember token can be deleted
    # once we're sure we're absolutely sure we won't roll this change back)
    execute "UPDATE users SET encrypted_password = crypted_password, remember_token = persistence_token"
  end

  def self.down
    change_table :users do |t|
      t.remove :encrypted_password,:confirmation_token,:remember_token
    end
  end
end