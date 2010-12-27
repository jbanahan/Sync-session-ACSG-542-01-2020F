module LinesSupport
  def set_line_number
    if self.line_number.nil? || self.line_number < 1
      max = nil
      max = self.class.where(parent_id_where).maximum(:line_number) unless parent_obj.nil?
      self.line_number = (max.nil? || max < 1) ? 1 : (max + 1)
    end
  end 
end