module OpenChain; module SupplementalTariffSupport
  extend ActiveSupport::Concern

  def supplemental_tariff? tariff_number
    is_301_tariff?(tariff_number) || mtb_tariff?(tariff_number) || supplemental_98_tariff?(tariff_number)
  end

  def mtb_tariff? tariff_number
    tariff_number.to_s.starts_with?("9902")
  end

  def is_301_tariff? tariff_number
    tariff_number.to_s.starts_with?("9903")
  end

  # This all really should go into some sort of cross reference lookup
  # This list was generated by reading through the Chapter 98 tariff publication and
  # looking for Statistical Notes indicating that this number should be filed along w/ a
  # tariff from the corresponding Chapters 1-97
  SUPPLEMENTAL_98_TARIFFS = ['9802', '98080030', '98080040', '98080050', '98080070', '98080080', '98130005',
                             '98170050', '98170060', '98170080', '98170090', '98170092', '98170094', '98170096',
                             '98172901', '98172902', '98175701', '98176101', '98178201', '98178401', '98178501',
                             '98179501', '98179505', '98180005', '9819', '9820', '9822'].freeze

  def supplemental_98_tariff? tariff_number
    SUPPLEMENTAL_98_TARIFFS.any? {|t| tariff_number.starts_with? t }
  end

end; end