# == Schema Information
#
# Table name: duty_calc_import_file_lines
#
#  id                       :integer          not null, primary key
#  drawback_import_line_id  :integer
#  created_at               :datetime
#  updated_at               :datetime
#  duty_calc_import_file_id :integer
#
# Indexes
#
#  index_duty_calc_import_file_lines_on_drawback_import_line_id   (drawback_import_line_id)
#  index_duty_calc_import_file_lines_on_duty_calc_import_file_id  (duty_calc_import_file_id)
#

class DutyCalcImportFileLine < ActiveRecord::Base
  belongs_to :duty_calc_import_file
  belongs_to :drawback_import_line
end
