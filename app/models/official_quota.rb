class OfficialQuota < ActiveRecord::Base
  belongs_to :country
  belongs_to :official_tariff

  #test and rebuild link to tariff (need to run this after rebuilding tariff table)
  def link
    if self.official_tariff_id.nil? || OfficialTariff.where(:id=>self.official_tariff_id).first.nil?
      self.official_tariff = OfficialTariff.where(:country_id=>self.country_id,:hts_code=>self.hts_code).first
    end
  end

  def self.relink_country country
    OfficialQuota.where(:country_id=>country).each do |q|
      q.link
      q.save
    end
  end

end
