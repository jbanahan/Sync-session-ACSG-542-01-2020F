class AddSystemCodeToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :system_code, :string
  end

  def self.down
    remove_column :master_setups, :system_code
  end
end
