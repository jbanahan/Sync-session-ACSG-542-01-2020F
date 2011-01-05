module LinesSupport
  def set_line_number
    if self.line_number.nil? || self.line_number < 1
      max = nil
      max = self.class.where(parent_id_where).maximum(:line_number) unless parent_obj.nil?
      self.line_number = (max.nil? || max < 1) ? 1 : (max + 1)
    end
  end 
  
  def make_unpacked_piece_set
    set_qty = self.ordered_qty - self.piece_sets.sum("quantity") 
    ps = self.piece_sets.build
    ps.product_id = self.product_id
    ps.quantity = set_qty < 0 ? 0 : set_qty
    return ps
  end
end