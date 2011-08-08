class AddTargetVersionToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :target_version, :string
  end

  def self.down
    remove_column :master_setups, :target_version
  end
end
