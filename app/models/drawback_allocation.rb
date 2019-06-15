# == Schema Information
#
# Table name: drawback_allocations
#
#  created_at                    :datetime         not null
#  drawback_import_line_id       :integer
#  duty_calc_export_file_line_id :integer
#  id                            :integer          not null, primary key
#  quantity                      :decimal(13, 4)
#  updated_at                    :datetime         not null
#
# Indexes
#
#  index_drawback_allocations_on_drawback_import_line_id        (drawback_import_line_id)
#  index_drawback_allocations_on_duty_calc_export_file_line_id  (duty_calc_export_file_line_id)
#

class DrawbackAllocation < ActiveRecord::Base
  attr_accessible :drawback_import_line_id, :duty_calc_export_file_line_id, :quantity
  
  belongs_to :duty_calc_export_file_line
  belongs_to :drawback_import_line
end
