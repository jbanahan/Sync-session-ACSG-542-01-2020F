class AddImportDateSplitShipmentFieldsToEntries < ActiveRecord::Migration
  def change
    change_table :entries, bulk:true do |t|
      t.date :import_date
      t.boolean :split_shipment
      t.string :split_release_option
    end
  end
end
