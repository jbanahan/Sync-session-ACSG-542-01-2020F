class AddGoogleAuthToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :google_name, :string
    add_column :users, :oauth_token, :string
    add_column :users, :oauth_expires_at, :datetime
  end

  def self.down
    remove_column :users, :provider
    remove_column :users, :uid
    remove_column :users, :google_name
    remove_column :users, :oauth_token
    remove_column :users, :oauth_expires_at
  end
end
