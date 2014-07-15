require 'open_chain/stat_client'
class OfficialTariff < ActiveRecord::Base

  LACEY_CODES ||= ["4401","4402","4403","4404","4406","4407","4408","4409",
                    "4412", "4414", "4417", "4418", "4419", "4420", "4421",
                    "6602", "8201", "9201", "9202", "9302", "93051020",
                    "940169", "950420", "9703"]

  after_commit :update_cache
  before_save :set_common_rate

  belongs_to :country
  has_one :official_quota

  validates :country, :presence => true
  validates :hts_code, :presence => true
  
  validates :hts_code, :uniqueness => {:scope => :country_id}

  def lacey_act?
    return false if self.country.iso_code != "US"

    LACEY_CODES.each do |prefix|
      return true if self.hts_code.starts_with?(prefix)
    end

    return false
  end

  def lacey_act
    #JSON doesn't like sending methods that end in a question mark.  I'm keeping the "?"
    #version because it's more intuitive. This is ONLY used for the controller's #find render.
    return lacey_act?
  end

  def self.run_schedulable
    update_use_count
  end
  
  #update the database with the total number of times that each official tariff has been used
  def self.update_use_count
    OpenChain::StatClient.wall_time('ot_use') do
      conn = ActiveRecord::Base.connection
      countries = Country.where("id IN (SELECT DISTINCT country_id from classifications)")
      countries.each do |c|
        hts_hash = {}
        (1..3).each do |i|
          r = conn.execute "select hts_#{i} as \"HTS\", count(*) from tariff_records
  inner join classifications on classifications.id = tariff_records.classification_id
  where length(hts_#{i}) > 0 and classifications.country_id = #{c.id}
  group by hts_#{i}"
          r.each do |row|
            hts_hash[row[0]] ||= 0
            hts_hash[row[0]] += row[1]
          end
        end
        job_start = conn.execute("SELECT now()").first.first     
        hts_hash.each do |k,v|
           conn.execute "UPDATE official_tariffs SET use_count = #{v}, updated_at = now() WHERE country_id = #{c.id} AND hts_code = \"#{k}\"; "
        end
        qr = OfficialTariff.where(country_id:c.id).where("use_count is null OR updated_at < ?",job_start).update_all(use_count:0)
      end
    end
  end

  #get hash of auto-classification results keyed by country object
  def self.auto_classify base_hts
    return {} if base_hts.blank? || base_hts.strip.size < 6 #only works on 6 digit or longer
    to_test = base_hts[0,6]
    r = {}
    OfficialTariff.joins(:country).where("hts_code like ?","#{to_test}%").where("countries.import_location = ?",true).order("official_tariffs.use_count DESC, official_tariffs.hts_code ASC").each do |ot|
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
