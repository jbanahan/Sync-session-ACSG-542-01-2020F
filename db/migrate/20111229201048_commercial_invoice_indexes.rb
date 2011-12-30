class CommercialInvoiceIndexes < ActiveRecord::Migration
  def self.up
    add_index :commercial_invoices, :entry_id
    add_index :commercial_invoices, :invoice_number
    add_index :commercial_invoices, :invoice_date
    add_index :commercial_invoice_lines, :commercial_invoice_id
    add_index :commercial_invoice_lines, :part_number
    add_index :commercial_invoice_lines, :hts_number
  end

  def self.down
    remove_index :commercial_invoices, :entry_id
    remove_index :commercial_invoices, :invoice_number
    remove_index :commercial_invoices, :invoice_date
    remove_index :commercial_invoice_lines, :commercial_invoice_id
    remove_index :commercial_invoice_lines, :part_number
    remove_index :commercial_invoice_lines, :hts_number
  end
end
