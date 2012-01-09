class AddEntryEnabledToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :entry_enabled, :boolean
  end

  def self.down
    remove_column :master_setups, :entry_enabled
  end
end
