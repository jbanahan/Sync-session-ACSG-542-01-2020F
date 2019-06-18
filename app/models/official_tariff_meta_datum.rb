# == Schema Information
#
# Table name: official_tariff_meta_datas
#
#  auto_classify_ignore :boolean
#  country_id           :integer
#  created_at           :datetime         not null
#  hts_code             :string(255)
#  id                   :integer          not null, primary key
#  notes                :text(65535)
#  summary_description  :string(255)
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_official_tariff_meta_datas_on_country_id_and_hts_code  (country_id,hts_code)
#

class OfficialTariffMetaDatum < ActiveRecord::Base
  attr_accessible :auto_classify_ignore, :country, :country_id, :hts_code, 
    :notes, :summary_description
  
  validates :country_id, :presence=>true
  validates :hts_code, :presence=>true
  self.table_name = :official_tariff_meta_datas

  belongs_to :country

  #get's the associated official_tariff object
  def official_tariff(use_cache=true)
    @official_tariff = OfficialTariff.find_cached_by_hts_code_and_country_id self.hts_code, self.country_id if use_cache && @official_tariff.nil?
    @official_tariff = OfficialTariff.where(:country_id=>self.country_id).where(:hts_code=>self.hts_code).first if @official_tariff.nil?
    @official_tariff
  end

end
