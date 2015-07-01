class AddContainerIdToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :container_id, :integer
    add_index :commercial_invoice_lines, :container_id
  end
end
