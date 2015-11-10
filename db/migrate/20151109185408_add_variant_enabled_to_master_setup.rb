class AddVariantEnabledToMasterSetup < ActiveRecord::Migration
  def change
    add_column :master_setups, :variant_enabled, :boolean
  end
end
