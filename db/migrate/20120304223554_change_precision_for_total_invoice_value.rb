class ChangePrecisionForTotalInvoiceValue < ActiveRecord::Migration
  def self.up
    remove_column :drawback_import_lines, :total_invoice_value
    add_column :drawback_import_lines, :total_invoice_value, :decimal, :precision=>10, :scale=>2
  end

  def self.down
    remove_column :drawback_import_lines, :total_invoice_value
    add_column :drawback_import_lines, :total_invoice_value, :decimal
  end
end
