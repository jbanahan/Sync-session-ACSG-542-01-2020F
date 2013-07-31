class AddTotalQuantityAndTotalQuantityUomToCommercialInvoices < ActiveRecord::Migration
  def change
    add_column :commercial_invoices, :total_quantity, :decimal, :precision=>12, :scale=>5
    add_column :commercial_invoices, :total_quantity_uom, :string
  end
end
