class AddMiscDiscountsToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :miscellaneous_discount, :decimal, :precision => 12, :scale => 2
  end
end
