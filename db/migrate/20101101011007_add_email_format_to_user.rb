class AddEmailFormatToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :email_format, :string
  end

  def self.down
    remove_column :users, :email_format
  end
end
