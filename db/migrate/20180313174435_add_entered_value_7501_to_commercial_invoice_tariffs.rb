class AddEnteredValue7501ToCommercialInvoiceTariffs < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_tariffs, :entered_value_7501, :integer
  end
end
