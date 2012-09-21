class AddImporterIdToShipmentAndDrawback < ActiveRecord::Migration
  def self.up
    add_column :drawback_import_lines, :importer_id, :integer
    add_index :drawback_import_lines, :importer_id
    add_column :duty_calc_import_files, :importer_id, :integer
    add_index :duty_calc_import_files, :importer_id
    add_column :shipments, :importer_id, :integer
    add_index :shipments, :importer_id
  end

  def self.down
    remove_index :shipments, :importer_id
    remove_column :shipments, :importer_id
    remove_index :duty_calc_import_files, :importer_id
    remove_column :duty_calc_import_files, :importer_id
    remove_index :drawback_import_lines, :importer_id
    remove_column :drawback_import_lines, :importer_id
  end
end
