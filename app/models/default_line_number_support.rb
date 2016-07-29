module DefaultLineNumberSupport
  extend ActiveSupport::Concern

  def default_line_number
    if self.line_number.nil? || self.line_number < 1
      max = nil
      my_association = self.class.name.tableize
      p = parent_obj
      max = p.send(my_association.to_sym).collect {|o| o.line_number}.compact.sort.last unless p.nil?
      self.line_number = (max.nil? || max < 1) ? 1 : (max + 1)
    end
  end

end