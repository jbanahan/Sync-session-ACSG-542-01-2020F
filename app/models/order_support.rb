module OrderSupport
  def make_unpacked_piece_sets
    r = Array.new
    get_lines.each do |line|
      r << line.make_unpacked_piece_set
    end
    return r
  end
end