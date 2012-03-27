class AddVendorAndImporterToCommercialInvoice < ActiveRecord::Migration
  def self.up
    add_column :commercial_invoices, :vendor_id, :integer
    add_column :commercial_invoices, :importer_id, :integer
    execute <<-SQL
      UPDATE commercial_invoices inv
        SET importer_id = (
          SELECT ent.importer_id 
          FROM entries ent 
          WHERE ent.id = inv.entry_id)
    SQL
  end

  def self.down
    remove_column :commercial_invoices, :importer_id
    remove_column :commercial_invoices, :vendor_id
  end
end
