class AddVendorAndImporterToCommercialInvoice < ActiveRecord::Migration
  def self.up
    add_column :commercial_invoices, :vendor_id, :integer
    add_column :commercial_invoices, :importer_id, :integer
  end

  def self.down
    remove_column :commercial_invoices, :importer_id
    remove_column :commercial_invoices, :vendor_id
  end
end
