class OfficialTariffSpi < ActiveRecord::Base
  belongs_to :official_tariff, inverse_of: :official_tariff_spis

  def can_view? user
    return self.official_tariff && self.official_tariff.can_view?(user)
  end
end
