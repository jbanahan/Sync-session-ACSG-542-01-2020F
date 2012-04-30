class DutyCalcImportFileLine < ActiveRecord::Base
  belongs_to :duty_calc_import_file
  belongs_to :drawback_import_line
end
