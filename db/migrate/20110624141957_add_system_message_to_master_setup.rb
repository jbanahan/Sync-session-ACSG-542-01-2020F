class AddSystemMessageToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :system_message, :text
  end

  def self.down
    remove_column :master_setups, :system_message
  end
end
