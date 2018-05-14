class AddIndexesToInvoiceLines < ActiveRecord::Migration
  def self.up
    add_index :invoice_lines, :po_number
    add_index :invoice_lines, :part_number
  end

  def self.down
    remove_index :invoice_lines, :po_number
    remove_index :invoice_lines, :part_number
  end
end
