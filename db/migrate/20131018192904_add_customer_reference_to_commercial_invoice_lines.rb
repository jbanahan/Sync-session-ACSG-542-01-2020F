class AddCustomerReferenceToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :customer_reference, :string
  end
end
