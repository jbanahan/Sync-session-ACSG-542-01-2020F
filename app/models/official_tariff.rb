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
    t = CACHE.get("OfficialTariff:ct:#{hts_code.strip}:#{country_id}")
    t = OfficialTariff.where(:country_id=>country_id,:hts_code=>hts_code).first if t.nil?
    CACHE.set("OfficialTariff:ct:#{hts_code.strip}:#{country_id}",t) unless t.nil?
    t
  end

  #return all potential tariffs that match at the 6 digit level
  def find_matches(other_country)
    h = self.hts_code.length > 6 ? self.hts_code[0,6] : self.hts_code
    OfficialTariff.where(:country_id=>other_country).where("hts_code like ?","#{h}%")
  end

  def meta_data
    @meta_data = OfficialTariffMetaData.where(:country_id=>self.country_id,:hts_code=>self.hts_code).first if @meta_data.nil?
    @meta_data = OfficialTariffMetaData.new(:country_id=>self.country_id,:hts_code=>self.hts_code) if @meta_data.nil?
    @meta_data
  end

  #override as_json to format hts_code
  def as_json(options={})
    result = super({ :except => :hts_code }.merge(options))
    otr = result["official_tariff"]
    otr["hts_code"] = hts_code.hts_format unless hts_code.nil?
    md = self.meta_data
    unless md.nil?
      otr["notes"]=md.notes.nil? ? "" : md.notes
      otr["auto_classify_ignore"] = md.auto_classify_ignore ? true : false
    end
    result
  end

  private
  def update_cache
    CACHE.set "OfficialTariff:ct:#{self.hts_code.strip}:#{self.country_id}", self
  end
end
