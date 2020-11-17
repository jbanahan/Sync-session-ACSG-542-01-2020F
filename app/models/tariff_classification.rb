# == Schema Information
#
# Table name: tariff_classifications
#
#  antidumping_duty          :boolean
#  base_rate_indicator       :string(255)
#  blocked_record            :boolean
#  countervailing_duty       :boolean
#  country_id                :integer
#  created_at                :datetime         not null
#  duty_computation          :string(255)
#  effective_date_end        :date
#  effective_date_start      :date
#  id                        :integer          not null, primary key
#  last_exported_from_source :datetime
#  number_of_reporting_units :decimal(10, 2)
#  tariff_description        :string(255)
#  tariff_number             :string(255)
#  unit_of_measure_1         :string(255)
#  unit_of_measure_2         :string(255)
#  unit_of_measure_3         :string(255)
#  updated_at                :datetime         not null
#
# Indexes
#
#  idx_tariff_classifications_on_number_country_effective_date  (tariff_number,country_id,effective_date_start) UNIQUE
#

class TariffClassification < ActiveRecord::Base
  has_many :tariff_classification_rates, inverse_of: :tariff_classification, dependent: :destroy, autosave: true
  belongs_to :country

  def self.find_effective_tariff country, effective_date, tariff_number, include_rates: true
    query = TariffClassification.where(tariff_number: tariff_number.to_s.strip.gsub(".", ""))
    query = add_effective_date_parameters(query, effective_date)
    query = add_country_parameter(query, country)

    if include_rates
      query = query.includes(:tariff_classification_rates)
    end

    # There really shouldn't be overlapping tariffs, but if there are..choose the one closest to the given effective date
    query.order("effective_date_start DESC").first
  end

  def self.add_effective_date_parameters active_record_statement, effective_date
    active_record_statement = active_record_statement.where("effective_date_start <= ?", effective_date)
    active_record_statement.where("effective_date_end IS NULL OR effective_date_end >= ?", effective_date)
  end

  def self.add_country_parameter active_record_statement, country
    if country.is_a?(String)
      return active_record_statement.joins(:country).where(countries: {iso_code: country})
    elsif country.is_a?(Numeric)
      return active_record_statement.where(country_id: country.to_i)
    elsif country.is_a?(Country)
      return active_record_statement.where(country_id: country.id)
    else
      raise "Expected a String ISO Code, Numeric country id or Country object but received #{country.inspect}"
    end
  end

  # This method pulls all the rate information needed about a tariff record from the classification data / rates.
  # It returns a hash with the following keys: advalorem_rate, specific_rate, specific_rate_uom, additional_rate,
  # additional_rate_uom.
  #
  # country_origin - the iso code of the country of origin for the product being imported (can be nil).
  # spi - any SPI code being claimed for the product being imported (can be nil)
  #
  # If both country origin / spi are blank, then the primary rate for the tariff is utilized.
  def extract_tariff_rate_data country_origin_iso, spi
    # The implementation below is for US.  Not sure if we will every have to use this for other countries, but
    # at them moment, this is US only, so I'm going to just put this rate stuff here.

    # For now, the effective date is not used...it might be required in the future if any countries are added or removed
    # from the Normal Trade Relations list.  For the moment, only Cuba and North Korea on on there
    code = "01"
    if ["KP", "CU"].include? country_origin_iso
      code = "02"
    elsif spi.present?
      code = spi
    end

    rate = self.tariff_classification_rates.find { |r| r.special_program_indicator == code }

    # Note: We're expecting if a specific or additional rate isn't utilized that the value will
    # be nil in the rate object.
    rate_data = {
      advalorem_rate: BigDecimal("0"),
      specific_rate: BigDecimal("0"), specific_rate_uom: nil,
      additional_rate: BigDecimal("0"), additional_rate_uom: nil
    }

    case self.duty_computation.to_s.upcase
    when "0"
      # Duty Free
    when "1"
      rate_data[:specific_rate] = rate&.rate_specific
      rate_data[:specific_rate_uom] = unit_of_measure_1
    when "2"
      rate_data[:specific_rate] = rate&.rate_specific
      rate_data[:specific_rate_uom] = unit_of_measure_2
    when "3"
      rate_data[:specific_rate] = rate&.rate_specific
      rate_data[:specific_rate_uom] = unit_of_measure_1
      rate_data[:additional_rate] = rate&.rate_additional
      rate_data[:additional_rate_uom] = unit_of_measure_2
    when "4"
      rate_data[:specific_rate] = rate&.rate_specific
      rate_data[:specific_rate_uom] = unit_of_measure_1
      rate_data[:advalorem_rate] = rate&.rate_advalorem
    when "5"
      rate_data[:specific_rate] = rate&.rate_specific
      rate_data[:specific_rate_uom] = unit_of_measure_2
      rate_data[:advalorem_rate] = rate&.rate_advalorem
    when "6"
      rate_data[:specific_rate] = rate&.rate_specific
      rate_data[:specific_rate_uom] = unit_of_measure_1
      rate_data[:additional_rate] = rate&.rate_additional
      rate_data[:additional_rate_uom] = unit_of_measure_2
      rate_data[:advalorem_rate] = rate&.rate_advalorem
    when "7"
      rate_data[:advalorem_rate] = rate&.rate_advalorem
    end

    rate_data
  end
end
