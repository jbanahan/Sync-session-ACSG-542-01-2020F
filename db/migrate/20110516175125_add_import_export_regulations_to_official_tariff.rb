class AddImportExportRegulationsToOfficialTariff < ActiveRecord::Migration
  def self.up
    add_column :official_tariffs, :import_regulations, :string
    add_column :official_tariffs, :export_regulations, :string
  end

  def self.down
    remove_column :official_tariffs, :export_regulations
    remove_column :official_tariffs, :import_regulations
  end
end
