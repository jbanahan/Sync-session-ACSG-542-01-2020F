class CreateDutyCalcImportFiles < ActiveRecord::Migration
  def self.up
    create_table :duty_calc_import_files do |t|
      t.integer :user_id

      t.timestamps
    end
  end

  def self.down
    drop_table :duty_calc_import_files
  end
end
