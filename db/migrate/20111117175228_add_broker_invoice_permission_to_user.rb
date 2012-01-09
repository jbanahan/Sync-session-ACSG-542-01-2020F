class AddBrokerInvoicePermissionToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :broker_invoice_view, :boolean
  end

  def self.down
    remove_column :users, :broker_invoice_view
  end
end
