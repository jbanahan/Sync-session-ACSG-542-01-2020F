class AddHostWithPortToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :host_with_port, :string
  end

  def self.down
    remove_column :users, :host_with_port
  end
end
