class OfficialTariff < ActiveRecord::Base

  after_commit :update_cache
  before_save :set_common_rate

  belongs_to :country
  has_one :official_quota

  validates :country, :presence => true
  validates :hts_code, :presence => true
  
  validates :hts_code, :uniqueness => {:scope => :country_id}
  
  #update the database with the total number of times that each official tariff has been used
  def self.update_use_count
    ActiveRecord::Base.connection.execute "UPDATE official_tariffs SET use_count = (
SELECT 
(SELECT count(tariff_records.id) FROM tariff_records
INNER JOIN classifications ON classifications.id = tariff_records.classification_id 
WHERE tariff_records.hts_1 = official_tariffs.hts_code 
AND classifications.country_id = official_tariffs.country_id
) +
(SELECT count(tariff_records.id) FROM tariff_records
INNER JOIN classifications ON classifications.id = tariff_records.classification_id 
WHERE tariff_records.hts_2 = official_tariffs.hts_code 
AND classifications.country_id = official_tariffs.country_id
) +
(SELECT count(tariff_records.id) FROM tariff_records
INNER JOIN classifications ON classifications.id = tariff_records.classification_id 
WHERE tariff_records.hts_3 = official_tariffs.hts_code 
AND classifications.country_id = official_tariffs.country_id
) 
)"
  end

  #get hash of auto-classification results keyed by country object
  def self.auto_classify base_hts
    return {} if base_hts.blank? || base_hts.strip.size < 6 #only works on 6 digit or longer
    to_test = base_hts[0,6]
    r = {}
    OfficialTariff.joins(:country).where("hts_code like ?","#{to_test}%").where("countries.import_location = ?",true).order("official_tariffs.hts_code ASC").each do |ot|
      r[ot.country] ||= []
      r[ot.country] << ot
    end
    r
  end

  #address for external link to certain countries' binding ruling databases
  def binding_ruling_url
    return nil if self.country.nil? || self.hts_code.nil?
    if self.country.iso_code == 'US'
      return "http://rulings.cbp.gov/index.asp?qu=#{self.hts_code.hts_format.gsub(/\./,"%2E")}&vw=results" 
    elsif self.country.european_union?
      return "http://ec.europa.eu/taxation_customs/dds2/ebti/ebti_consultation.jsp?Lang=en&nomenc=#{six_digit_hts}&orderby=0&Expand=true&offset=1&range=25"
    end
    nil
  end
  #return tariff for hts_code & country_id
  def self.find_cached_by_hts_code_and_country_id hts_code, country_id
    t = CACHE.get("OfficialTariff:ct:#{hts_code.strip}:#{country_id}")
    t = OfficialTariff.where(:country_id=>country_id,:hts_code=>hts_code).first if t.nil?
    CACHE.set("OfficialTariff:ct:#{hts_code.strip}:#{country_id}",t) unless t.nil?
    t
  end

  #return all potential tariffs that match at the 6 digit level
  def find_matches(other_country)
    h = six_digit_hts
    OfficialTariff.where(:country_id=>other_country).where("hts_code like ?","#{h}%")
  end

  def find_schedule_b_matches
    OfficialScheduleBCode.where("hts_code like ?","#{six_digit_hts}%")
  end

  def meta_data
    @meta_data = OfficialTariffMetaDatum.where(:country_id=>self.country_id,:hts_code=>self.hts_code).first if @meta_data.nil?
    @meta_data = OfficialTariffMetaDatum.new(:country_id=>self.country_id,:hts_code=>self.hts_code) if @meta_data.nil?
    @meta_data
  end

  #override as_json to format hts_code
  def as_json(options={})
    result = super({ :except => :hts_code }.merge(options.nil? ? {} : options))
    otr = result["official_tariff"]
    otr["hts_code"] = hts_code.hts_format unless hts_code.nil?
    md = self.meta_data
    unless md.nil?
      otr["notes"]=md.notes.nil? ? "" : md.notes
      otr["auto_classify_ignore"] = md.auto_classify_ignore ? true : false
    end
    br = binding_ruling_url
    otr["binding_ruling_url"] = br unless br.nil?
    result
  end

  def self.search_secure user, base
    base.where(search_where(user))
  end
  def can_view? u
    u.view_official_tariffs? 
  end
  def self.search_where user
    user.view_official_tariffs? ? "1=1" : "1=0"
  end
  private
  def update_cache
    CACHE.set "OfficialTariff:ct:#{self.hts_code.strip}:#{self.country_id}", self
  end

  def six_digit_hts
    self.hts_code.length > 6 ? self.hts_code[0,6] : self.hts_code
  end

  def set_common_rate
    if self.country_id
      country = Country.find_cached_by_id self.country_id
      if ['CA','CN'].include? country.iso_code
        self.common_rate = self.most_favored_nation_rate
      elsif country.european_union?
        self.common_rate = self.erga_omnes_rate
      else
        self.common_rate = self.general_rate
      end
    end
  end

end
