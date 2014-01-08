class AddProjectEnabledToMasterSetup < ActiveRecord::Migration
  def change
    add_column :master_setups, :project_enabled, :boolean
  end
end
