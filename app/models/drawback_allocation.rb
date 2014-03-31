class DrawbackAllocation < ActiveRecord::Base
  belongs_to :duty_calc_export_file_line
  belongs_to :drawback_import_line
end
