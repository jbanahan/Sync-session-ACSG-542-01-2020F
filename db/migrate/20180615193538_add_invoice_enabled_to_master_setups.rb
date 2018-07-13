class AddInvoiceEnabledToMasterSetups < ActiveRecord::Migration
  def change
    add_column :master_setups, :invoices_enabled, :boolean
  end
end
