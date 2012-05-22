class AddIndexesToDrawbackLines < ActiveRecord::Migration
  def self.up
    add_index :duty_calc_export_file_lines, :part_number
    add_index :duty_calc_export_file_lines, :ref_1
    add_index :duty_calc_export_file_lines, :ref_2
    add_index :drawback_import_lines, :part_number
  end

  def self.down
    remove_index :duty_calc_export_file_lines, :part_number
    remove_index :duty_calc_export_file_lines, :ref_1
    remove_index :duty_calc_export_file_lines, :ref_2
    remove_index :drawback_import_lines, :part_number
  end
end
