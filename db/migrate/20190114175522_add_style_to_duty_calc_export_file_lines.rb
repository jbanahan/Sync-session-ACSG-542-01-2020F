class AddStyleToDutyCalcExportFileLines < ActiveRecord::Migration
  def up
    change_table :duty_calc_export_file_lines, bulk:true do |t|
      t.string :style
      t.string :ref_5
      t.string :ref_6
    end

    change_table :drawback_import_lines, bulk:true do |t|
      t.string :style
      t.boolean :single_line
    end
  end

  def down
    remove_column :duty_calc_export_file_lines, :style
    remove_column :duty_calc_export_file_lines, :ref_5
    remove_column :duty_calc_export_file_lines, :ref_6
    remove_column :drawback_import_lines, :style
    remove_column :drawback_import_lines, :single_line
  end
end