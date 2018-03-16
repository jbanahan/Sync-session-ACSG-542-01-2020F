class AddEnteredValue7501ToCommercialInvoices < ActiveRecord::Migration
  def change
    add_column :commercial_invoices, :entered_value_7501, :integer
  end
end
