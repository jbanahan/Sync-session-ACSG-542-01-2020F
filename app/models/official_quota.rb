# == Schema Information
#
# Table name: official_quotas
#
#  category                       :string(255)
#  country_id                     :integer
#  created_at                     :datetime         not null
#  hts_code                       :string(255)
#  id                             :integer          not null, primary key
#  official_tariff_id             :integer
#  square_meter_equivalent_factor :decimal(13, 4)
#  unit_of_measure                :string(255)
#  updated_at                     :datetime         not null
#
# Indexes
#
#  index_official_quotas_on_country_id_and_hts_code  (country_id,hts_code)
#

class OfficialQuota < ActiveRecord::Base
  belongs_to :country
  belongs_to :official_tariff
  self.table_name = :official_quotas

  # test and rebuild link to tariff (need to run this after rebuilding tariff table)
  def link
    if self.official_tariff_id.nil? || OfficialTariff.where(:id=>self.official_tariff_id).first.nil?
      self.official_tariff = OfficialTariff.where(:country_id=>self.country_id, :hts_code=>self.hts_code).first
    end
  end

  def self.relink_country country
    OfficialQuota.where(:country_id=>country).each do |q|
      q.link
      q.save
    end
  end

end
