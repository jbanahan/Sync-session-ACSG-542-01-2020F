class AddNonDutiableAmountToCommercialInvoices < ActiveRecord::Migration
  def change
    add_column :commercial_invoices, :non_dutiable_amount, :decimal, precision: 13, scale: 2
  end
end
