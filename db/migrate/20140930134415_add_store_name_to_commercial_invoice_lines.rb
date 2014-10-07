class AddStoreNameToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :store_name, :string
  end
end
