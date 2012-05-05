class FixdutyCalcImportFileIdFk < ActiveRecord::Migration
  def self.up
    add_column :duty_calc_import_file_lines, :duty_calc_import_file_id, :integer
    execute "UPDATE duty_calc_import_file_lines SET duty_calc_import_file_id = duty_calc_file_id"
    remove_column :duty_calc_import_file_lines, :duty_calc_file_id
    add_index :duty_calc_import_file_lines, :duty_calc_import_file_id
  end

  def self.down
  end
end
