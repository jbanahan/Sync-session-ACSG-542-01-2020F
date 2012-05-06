class DutyCalcExportFile < ActiveRecord::Base
  has_many :duty_calc_export_file_lines, :dependent=>:destroy
end
