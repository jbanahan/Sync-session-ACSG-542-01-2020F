# == Schema Information
#
# Table name: carton_sets
#
#  id              :integer          not null, primary key
#  starting_carton :integer
#  carton_qty      :integer
#  length_cm       :decimal(8, 4)
#  width_cm        :decimal(8, 4)
#  height_cm       :decimal(8, 4)
#  net_net_kgs     :decimal(8, 4)
#  net_kgs         :decimal(8, 4)
#  gross_kgs       :decimal(8, 4)
#  shipment_id     :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_carton_sets_on_shipment_id  (shipment_id)
#

class CartonSet < ActiveRecord::Base
  belongs_to :shipment, inverse_of: :carton_sets
  has_many :shipment_lines, inverse_of: :carton_set

  def total_gross_kgs decimal_places = 2
    val = BigDecimal.new(self.carton_qty.presence || 0) * (self.gross_kgs.presence || 0)
    val.round(decimal_places)
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

  def total_volume_cubic_centimeters 
    total = BigDecimal(0)
    if self.length_cm && self.width_cm && self.height_cm
      volume = (self.length_cm * self.width_cm * self.height_cm)
    end

    BigDecimal.new(self.carton_qty.presence || 0) * (volume.presence || 0)
  end
end
