class CartonSet < ActiveRecord::Base
  belongs_to :shipment, inverse_of: :carton_sets
  has_many :shipment_lines, inverse_of: :carton_set

  def total_gross_kgs
    BigDecimal.new(self.carton_qty.presence || 0) * (self.gross_kgs.presence || 0)
  end

  def total_volume_cbms decimal_places = 2
    total = BigDecimal(0)
    if self.length_cm && self.width_cm && self.height_cm
      volume = (self.length_cm * self.width_cm * self.height_cm) / BigDecimal(1000000)
    end

    total = BigDecimal.new(self.carton_qty.presence || 0) * (volume.presence || 0)
    if decimal_places.to_i > 0
      total = total.round(decimal_places)
    end

    total
  end 
end
