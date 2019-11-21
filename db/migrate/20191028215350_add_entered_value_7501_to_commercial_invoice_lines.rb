class AddEnteredValue7501ToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :entered_value_7501, :integer
  end
end
