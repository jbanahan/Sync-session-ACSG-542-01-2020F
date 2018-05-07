class DefaultCountrySelector
  def self.call
    Country.where(active_origin: true).map {|c| [c.id, "#{c.iso_code} - #{c.name}"]}
  end
end