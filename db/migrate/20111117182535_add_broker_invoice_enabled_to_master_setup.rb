class AddBrokerInvoiceEnabledToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :broker_invoice_enabled, :boolean
  end

  def self.down
    remove_column :master_setups, :broker_invoice_enabled
  end
end
