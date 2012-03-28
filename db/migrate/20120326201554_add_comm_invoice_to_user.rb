class AddCommInvoiceToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :commercial_invoice_view, :boolean
    add_column :users, :commercial_invoice_edit, :boolean
    execute <<-SQL
      UPDATE users SET commercial_invoice_view = entry_view
    SQL
  end

  def self.down
    remove_column :users, :commercial_invoice_edit
    remove_column :users, :commercial_invoice_view
  end
end
