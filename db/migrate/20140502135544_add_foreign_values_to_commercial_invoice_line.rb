class AddForeignValuesToCommercialInvoiceLine < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :value_foreign, :decimal, precision: 11, scale: 2
    add_column :commercial_invoice_lines, :currency, :string
  end
end
