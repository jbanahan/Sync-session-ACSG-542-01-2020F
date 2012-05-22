class AddDrawbackIndexToDutyCalcImportFileLine < ActiveRecord::Migration
  def self.up
    add_index :duty_calc_import_file_lines, :drawback_import_line_id
  end

  def self.down
    remove_index :duty_calc_import_file_lines, :drawback_import_line_id
  end
end
