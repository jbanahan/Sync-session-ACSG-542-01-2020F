class AddVendorManagementEnabledToMasterSetup < ActiveRecord::Migration
  def change
    add_column :master_setups, :vendor_management_enabled, :boolean
  end
end
