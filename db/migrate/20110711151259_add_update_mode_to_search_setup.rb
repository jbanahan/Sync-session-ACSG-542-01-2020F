class AddUpdateModeToSearchSetup < ActiveRecord::Migration
  def self.up
    add_column :search_setups, :update_mode, :string
    execute "UPDATE `search_setups` SET `update_mode` = 'any'"
  end

  def self.down
    remove_column :search_setups, :update_mode
  end
end
