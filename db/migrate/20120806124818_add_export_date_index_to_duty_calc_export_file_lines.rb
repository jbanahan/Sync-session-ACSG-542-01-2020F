class AddExportDateIndexToDutyCalcExportFileLines < ActiveRecord::Migration
  def self.up
    add_index :duty_calc_export_file_lines, :export_date
  end

  def self.down
    remove_index :duty_calc_export_file_lines, :export_date
  end
end
