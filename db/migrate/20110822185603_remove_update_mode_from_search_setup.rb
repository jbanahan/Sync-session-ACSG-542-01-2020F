class RemoveUpdateModeFromSearchSetup < ActiveRecord::Migration
  def self.up
    remove_column :search_setups, :update_mode
  end

  def self.down
    add_column :search_setups, :update_mode, :string
  end
end
