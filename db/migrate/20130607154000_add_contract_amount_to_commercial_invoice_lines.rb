class AddContractAmountToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :contract_amount, :decimal, :precision=>12, :scale=>2 
  end
end
