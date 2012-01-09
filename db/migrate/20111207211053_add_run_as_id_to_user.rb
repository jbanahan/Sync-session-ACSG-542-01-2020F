class AddRunAsIdToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :run_as_id, :integer
  end

  def self.down
    remove_column :users, :run_as_id
  end
end
