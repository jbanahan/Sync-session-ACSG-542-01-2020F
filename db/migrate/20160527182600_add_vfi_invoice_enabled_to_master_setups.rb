class AddVfiInvoiceEnabledToMasterSetups < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :vfi_invoice_enabled, :boolean
  end

  def self.down
    remove_column :master_setups, :vfi_invoice_enabled
  end
end
