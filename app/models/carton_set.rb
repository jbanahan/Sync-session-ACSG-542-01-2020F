# == Schema Information
#
# Table name: carton_sets
#
#  carton_qty      :integer
#  created_at      :datetime         not null
#  gross_kgs       :decimal(8, 4)
#  height_cm       :decimal(8, 4)
#  id              :integer          not null, primary key
#  length_cm       :decimal(8, 4)
#  net_kgs         :decimal(8, 4)
#  net_net_kgs     :decimal(8, 4)
#  shipment_id     :integer
#  starting_carton :integer
#  updated_at      :datetime         not null
#  width_cm        :decimal(8, 4)
#
# Indexes
#
#  index_carton_sets_on_shipment_id  (shipment_id)
#

class CartonSet < ActiveRecord::Base
  attr_accessible :carton_qty, :gross_kgs, :height_cm, :length_cm, :net_kgs, :net_net_kgs, :shipment_id, :starting_carton, :width_cm

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
