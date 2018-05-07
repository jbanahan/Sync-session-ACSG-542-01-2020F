class DefaultPortSelector

  def self.call
    Port.where(active_origin: true).map {|p| [p.id, p.name] }
  end

end