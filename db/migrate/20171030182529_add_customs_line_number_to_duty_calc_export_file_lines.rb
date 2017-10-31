class AddCustomsLineNumberToDutyCalcExportFileLines < ActiveRecord::Migration
  def change

    change_table(:duty_calc_export_file_lines) do |t|
      t.integer :customs_line_number
    end
  end
end
