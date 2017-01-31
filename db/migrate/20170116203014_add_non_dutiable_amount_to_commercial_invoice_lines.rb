class AddNonDutiableAmountToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :non_dutiable_amount, :decimal, precision: 13, scale: 2
  end
end
