class AddVfiInvoiceEditAndVfiInvoiceViewToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :vfi_invoice_edit, :boolean
    add_column :users, :vfi_invoice_view, :boolean
  end

  def self.down
    remove_column :users, :vfi_invoice_edit
    remove_column :users, :vfi_invoice_view
  end
end
