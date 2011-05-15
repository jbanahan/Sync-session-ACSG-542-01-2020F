class OfficialTariff < ActiveRecord::Base

  after_commit :update_cache

  belongs_to :country
  has_one :official_quota

  validates :country, :presence => true
  validates :hts_code, :presence => true
  validates :full_description, :presence => true
  
  validates :hts_code, :uniqueness => {:scope => :country_id}
  
  #return tariff for hts_code & country_id
  def self.find_cached_by_hts_code_and_country_id hts_code, country_id
    t = CACHE.get("OfficialTariff:ct:#{hts_code}:#{country_id}")
    t = OfficialTariff.where(:country_id=>country_id,:hts_code=>hts_code).first if t.nil?
    CACHE.set("OfficialTariff:ct:#{hts_code}:#{country_id}",t) unless t.nil?
    t
  end

  #return all potential tariffs that match at the 6 digit level
  def find_matches(other_country)
    h = self.hts_code.length > 6 ? self.hts_code[0,6] : self.hts_code
    OfficialTariff.where(:country_id=>other_country).where("hts_code like ?","#{h}%")
  end

  #override as_json to format hts_code
  def as_json(options={})
    result = super({ :except => :hts_code }.merge(options))
    result["official_tariff"]["hts_code"] = hts_code.hts_format unless hts_code.nil?
    result
  end

  private
  def update_cache
    CACHE.set "OfficialTariff:ct:#{self.hts_code}:#{self.country_id}", self
  end
end
