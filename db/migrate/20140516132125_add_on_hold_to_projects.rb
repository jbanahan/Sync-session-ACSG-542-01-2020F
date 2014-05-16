class AddOnHoldToProjects < ActiveRecord::Migration
  def self.up
    add_column :projects, :on_hold, :boolean
  end

  def self.down
    remove_column :projects, :on_hold
  end
end
