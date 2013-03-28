class AddCommercialInvoiceNumbersToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :commercial_invoice_numbers, :text
  end
end
