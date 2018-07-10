# == Schema Information
#
# Table name: special_tariff_cross_references
#
#  country_origin_iso   :string(255)
#  created_at           :datetime         not null
#  effective_date_end   :date
#  effective_date_start :date
#  hts_number           :string(255)
#  id                   :integer          not null, primary key
#  special_hts_number   :string(255)
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_special_tariff_cross_references_on_hts_country_start_date  (hts_number,country_origin_iso,effective_date_start)
#

class SpecialTariffCrossReference < ActiveRecord::Base

  before_validation :clean_hts

  def self.find_special_tariff_hash reference_date: Time.zone.now.to_date, country_origin_iso: nil
    query = SpecialTariffCrossReference

    if reference_date
      query = query.where("effective_date_start <= ? OR effective_date_start IS NULL", reference_date)
      query = query.where("effective_date_end > ?  OR effective_date_end IS NULL", reference_date)
    end

    if country_origin_iso
      query = query.where(country_origin_iso: country_origin_iso)
    end

    results = {}
    query.each do |result|
      results[result.country_origin_iso.to_s] ||= SpecialTariffHash.new
      results[result.country_origin_iso.to_s].insert result
    end

    results
  end

  class SpecialTariffHash
    extend Forwardable

    def_delegators :@hash, :size, :delete, :clear, :empty?, :key?

    def initialize
      @hash = {}
    end

    def insert special_tariff
      raise IllegalArgumentError, "SpecialTariffHash only supports SpecialTariffCrossReference objects." unless special_tariff.is_a?(SpecialTariffCrossReference)

      @hash[special_tariff.hts_number] = special_tariff
    end

    def [] hts_number
      # What we're going to do is take the full number given and then work our way back through the hash such that we find the "best matching"
      # tariff (.ie the one with the most consecutive matching digits)
      begin 
        val = @hash[hts_number]
        return val unless val.nil?
      end while (hts_number = hts_number[0..-2]).try(:length).to_i > 2

      return nil
    end
  end

    private
      def clean_hts
        if !self.hts_number.blank?
          self.hts_number = self.hts_number.to_s.gsub(/[^0-9A-Za-z]/,'')
        end

        if !self.special_hts_number.blank?
          self.special_hts_number = self.special_hts_number.to_s.gsub(/[^0-9A-Za-z]/,'')
        end

        true
      end

end
