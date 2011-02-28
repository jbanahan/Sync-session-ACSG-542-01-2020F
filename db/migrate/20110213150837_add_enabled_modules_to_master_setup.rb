class AddEnabledModulesToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :order_enabled, :boolean, :null => false, :default => true
    add_column :master_setups, :shipment_enabled, :boolean, :null => false, :default => true
    add_column :master_setups, :sales_order_enabled, :boolean, :null => false, :default => true
    add_column :master_setups, :delivery_enabled, :boolean, :null => false, :default => true
    add_column :master_setups, :classification_enabled, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :master_setups, :classification_enabled
    remove_column :master_setups, :delivery_enabled
    remove_column :master_setups, :sales_order_enabled
    remove_column :master_setups, :shipment_enabled
    remove_column :master_setups, :order_enabled
  end
end
