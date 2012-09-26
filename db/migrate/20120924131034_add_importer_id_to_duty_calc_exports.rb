class AddImporterIdToDutyCalcExports < ActiveRecord::Migration
  def self.up
    add_column :duty_calc_export_files, :importer_id, :integer
    add_column :duty_calc_export_file_lines, :importer_id, :integer
    add_index :duty_calc_export_files, :importer_id
    add_index :duty_calc_export_file_lines, :importer_id
  end

  def self.down
    remove_index :duty_calc_export_file_lines, :importer_id
    remove_index :duty_calc_export_files, :importer_id
    remove_column :duty_calc_export_file_lines, :importer_id
    remove_column :duty_calc_export_files, :importer_id
  end
end
