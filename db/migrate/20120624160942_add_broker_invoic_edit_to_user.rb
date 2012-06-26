class AddBrokerInvoicEditToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :broker_invoice_edit, :boolean
  end

  def self.down
    remove_column :users, :broker_invoice_edit
  end
end
