class AddImporterReferenceToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :importer_reference, :string
    add_index :shipments, :importer_reference
  end
end
