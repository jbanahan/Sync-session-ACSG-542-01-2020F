class AddCommercialInvoiceImporterIdIndex < ActiveRecord::Migration
  def up
    add_index :commercial_invoices, :importer_id
  end

  def down
    remove_index :commercial_invoices, :importer_id
  end
end
