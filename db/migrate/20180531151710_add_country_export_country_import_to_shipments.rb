class AddCountryExportCountryImportToShipments < ActiveRecord::Migration
  def change
    change_table :shipments, bulk: true do |t|
      t.integer :country_export_id
      t.integer :country_import_id
    end
  end
end
