class AddOtherFeesToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :other_fees, :decimal, precision: 11, scale: 2
  end
end
