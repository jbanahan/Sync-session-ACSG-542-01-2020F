class DutyCalcImportFile < ActiveRecord::Base
  has_many :duty_calc_import_file_lines, :dependent=>:destroy
end
