class AddCustomFeaturesToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :custom_features, :text
  end

  def self.down
    remove_column :master_setups, :custom_features
  end
end
