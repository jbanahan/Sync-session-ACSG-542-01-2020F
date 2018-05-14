class AddIndexesToInvoices < ActiveRecord::Migration
  def self.up
    add_index :invoices, :importer_id
    add_index :invoices, :invoice_number
  end

  def self.down
    remove_index :invoices, :importer_id
    remove_index :invoices, :invoice_number
  end
end
