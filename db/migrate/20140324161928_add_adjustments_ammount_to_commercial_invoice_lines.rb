class AddAdjustmentsAmmountToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :adjustments_amount, :decimal, :precision => 12, :scale => 3
  end
end
