class CreateDutyCalcImportFileLines < ActiveRecord::Migration
  def self.up
    create_table :duty_calc_import_file_lines do |t|
      t.integer :duty_calc_file_id
      t.integer :drawback_import_line_id

      t.timestamps
    end
  end

  def self.down
    drop_table :duty_calc_import_file_lines
  end
end
