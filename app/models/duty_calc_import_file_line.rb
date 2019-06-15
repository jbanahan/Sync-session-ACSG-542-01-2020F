# == Schema Information
#
# Table name: duty_calc_import_file_lines
#
#  created_at               :datetime         not null
#  drawback_import_line_id  :integer
#  duty_calc_import_file_id :integer
#  id                       :integer          not null, primary key
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_duty_calc_import_file_lines_on_drawback_import_line_id   (drawback_import_line_id)
#  index_duty_calc_import_file_lines_on_duty_calc_import_file_id  (duty_calc_import_file_id)
#

class DutyCalcImportFileLine < ActiveRecord::Base
  attr_accessible :drawback_import_line_id, :duty_calc_import_file_id
  
  belongs_to :duty_calc_import_file
  belongs_to :drawback_import_line
end
