class AddDrawbackToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :drawback_enabled, :boolean
    add_column :users, :drawback_view, :boolean
    add_column :users, :drawback_edit, :boolean
  end

  def self.down
    remove_column :users, :drawback_view
    remove_column :users, :drawback_edit
    remove_column :master_setups, :drawback_enabled
  end
end
