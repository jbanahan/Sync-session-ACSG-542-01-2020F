class CustomReport < ActiveRecord::Base
  has_many :search_criterions, :dependent=>:destroy
  has_many :search_columns, :dependent=>:destroy
  has_many :search_schedules, :dependent=>:destroy
  
  def update_column_width sheet, column_number, content_width
    target_width = 8
    target_width = content_width if content_width > 8
    target_width = 23 if target_width > 23
    @column_widths ||= {}
    current_width = @column_widths[column_number]
    @column_widths[column_number] = target_width unless !current_width.nil? && current_width > target_width
    sheet.column(column_number).width = target_width unless @column_widths[column_number]==current_width
  end
end
