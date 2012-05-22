class CreateDutyCalcExportFileLines < ActiveRecord::Migration
  def self.up
    create_table :duty_calc_export_file_lines do |t|
      t.date :export_date
      t.date :ship_date
      t.string :part_number
      t.string :carrier
      t.string :ref_1
      t.string :ref_2
      t.string :ref_3
      t.string :ref_4
      t.string :destination_country
      t.decimal :quantity
      t.string :schedule_b_code
      t.string :hts_code
      t.string :description
      t.string :uom
      t.string :exporter
      t.string :status
      t.string :action_code
      t.decimal :nafta_duty
      t.decimal :nafta_us_equiv_duty
      t.decimal :nafta_duty_rate
      t.integer :duty_calc_export_file_id

      t.timestamps
    end

    add_index :duty_calc_export_file_lines, :duty_calc_export_file_id
  end

  def self.down
    drop_table :duty_calc_export_file_lines
  end
end
