# == Schema Information
#
# Table name: official_tariffs
#
#  add_valorem_rate                 :string(255)
#  calculation_method               :string(255)
#  chapter                          :text(65535)
#  column_2_rate                    :text(65535)
#  common_rate                      :string(255)
#  common_rate_decimal              :decimal(8, 4)
#  country_id                       :integer
#  created_at                       :datetime         not null
#  erga_omnes_rate                  :string(255)
#  export_regulations               :string(255)
#  fda_indicator                    :string(255)
#  full_description                 :text(65535)
#  general_preferential_tariff_rate :string(255)
#  general_rate                     :string(255)
#  heading                          :text(65535)
#  hts_code                         :string(255)
#  id                               :integer          not null, primary key
#  import_regulations               :string(255)
#  most_favored_nation_rate         :string(255)
#  per_unit_rate                    :string(255)
#  remaining_description            :text(65535)
#  special_rate_key                 :string(255)
#  special_rates                    :text(65535)
#  sub_heading                      :text(65535)
#  unit_of_measure                  :string(255)
#  updated_at                       :datetime         not null
#  use_count                        :integer
#
# Indexes
#
#  index_official_tariffs_on_country_id_and_hts_code  (country_id,hts_code)
#  index_official_tariffs_on_hts_code                 (hts_code)
#

require 'digest/md5'
require 'open_chain/stat_client'
class OfficialTariff < ActiveRecord::Base
  LACEY_CODES ||= ["4401", "4402", "4403", "4404", "4406", "4407", "4408", "4409",
                    "4412", "4414", "4417", "4418", "4419", "4420", "4421",
                    "6602", "8201", "9201", "9202", "9302", "93051020",
                    "940169", "950420", "9703"]

  after_commit :update_cache
  before_save :set_common_rate
  before_save :set_special_rate_key

  belongs_to :country
  has_one :official_quota

  validates :country, :presence => true
  validates :hts_code, :presence => true

  validates :hts_code, :uniqueness => {:scope => :country_id}

  def special_rate_keys
    SpecialRate.where(special_rate_key:self.special_rate_key, country_id:self.country_id)
  end

  def iso_code
    self.country ? self.country.iso_code : nil
  end

  def lacey_act?
    return false if self.country.iso_code != "US"

    LACEY_CODES.each do |prefix|
      return true if self.hts_code.starts_with?(prefix)
    end

    return false
  end

  def lacey_act
    # JSON doesn't like sending methods that end in a question mark.  I'm keeping the "?"
    # version because it's more intuitive. This is ONLY used for the controller's #find render.
    return lacey_act?
  end

  def self.run_schedulable
    update_use_count
  end

  def self.valid_hts? country, hts
    country_id = country.respond_to?(:id) ? country.id : country
    OfficialTariff.where(:country_id=>country_id, :hts_code=>hts).count > 0
  end

  # update the database with the total number of times that each official tariff has been used
  def self.update_use_count
    OpenChain::StatClient.wall_time('ot_use') do
      conn = ActiveRecord::Base.connection
      countries = Country.where("id IN (SELECT DISTINCT country_id from classifications)")
      countries.each do |c|
        hts_hash = {}
        (1..3).each do |i|
          query = "SELECT #{ActiveRecord::Base.connection.quote_column_name("hts_#{i}")} as \"HTS\", count(*) from tariff_records
  inner join classifications on classifications.id = tariff_records.classification_id
  where length(#{ActiveRecord::Base.connection.quote_column_name("hts_#{i}")}) > 0 and classifications.country_id = ?
  group by #{ActiveRecord::Base.connection.quote_column_name("hts_#{i}")}"

          r = conn.execute ActiveRecord::Base.sanitize_sql_array([query, c.id])
          r.each do |row|
            hts_hash[row[0]] ||= 0
            hts_hash[row[0]] += row[1]
          end
        end
        job_start = conn.execute("SELECT now()").first.first
        hts_hash.each do |k, v|
          # Add a second to avoid any rounding issues to cause the query below blanking the use counts to blank ones that shouldn't be
          OfficialTariff.where(country_id: c.id, hts_code: k).update_all use_count: v, updated_at: (job_start + 1.second)
        end
        OfficialTariff.where(country_id:c.id).where("use_count IS NULL OR updated_at < ?", job_start).update_all(use_count:0, updated_at: (job_start + 1.second))
      end
    end
  end

  # get hash of auto-classification results keyed by country object
  def self.auto_classify base_hts
    return {} if base_hts.blank? || base_hts.strip.size < 6 # only works on 6 digit or longer
    to_test = base_hts[0, 6]
    r = {}
    OfficialTariff.joins(:country).where("hts_code like ?", "#{to_test}%").where("countries.import_location = ?", true).order("official_tariffs.use_count DESC, official_tariffs.hts_code ASC").each do |ot|
      r[ot.country] ||= []
      r[ot.country] << ot
    end
    r
  end

  def taric_url
    return nil if self.country.nil? || !self.country.european_union?
    return "http://ec.europa.eu/taxation_customs/dds2/taric/measures.jsp?Taric=#{URI.encode(hts_code)}&LangDescr=en"
  end

  # address for external link to certain countries' binding ruling databases
  def binding_ruling_url
    return nil if self.country.nil? || self.hts_code.nil?
    if self.country.iso_code == 'US'
      return "https://rulings.cbp.gov/search?term=#{URI.encode(self.hts_code.hts_format)}&collection=ALL&sortBy=RELEVANCE&pageSize=30&page=1"
    elsif self.country.european_union?
      return "https://ec.europa.eu/taxation_customs/dds2/ebti/ebti_consultation.jsp?Lang=en&nomenc=#{URI.encode(six_digit_hts)}&orderby=1&Expand=true"
    end
    nil
  end

  # return tariff for hts_code & country_id
  def self.find_cached_by_hts_code_and_country_id hts_code, country_id
    # t = CACHE.get("OfficialTariff:ct:#{hts_code.strip}:#{country_id}")
    OfficialTariff.where(:country_id=>country_id, :hts_code=>hts_code).first
    # CACHE.set("OfficialTariff:ct:#{hts_code.strip}:#{country_id}",t) unless t.nil?
  end

  # return all potential tariffs that match at the 6 digit level
  def find_matches(other_country)
    h = six_digit_hts
    OfficialTariff.where(:country_id=>other_country).where("hts_code like ?", "#{h}%")
  end

  def find_schedule_b_matches
    OfficialScheduleBCode.where("hts_code like ?", "#{six_digit_hts}%")
  end

  def meta_data
    @meta_data = OfficialTariffMetaDatum.where(:country_id=>self.country_id, :hts_code=>self.hts_code).first if @meta_data.nil?
    @meta_data = OfficialTariffMetaDatum.new(:country_id=>self.country_id, :hts_code=>self.hts_code) if @meta_data.nil?
    @meta_data
  end

  # override as_json to format hts_code
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
    tr = taric_url
    otr["taric_url"] = tr unless tr.nil?
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

  # Returns the first (reading left to right) instance of a percentage found within a text rate value.  For example,
  # "This HTS rate contains two percentage values: 10.5% and 25%." would return 10.5 (as a BigDecimal).  If the value is not "Free",
  # and the string doesn't contain a number followed by a percent sign, nil is returned.  If the express_as_decimal flag is
  # provided as true (default is false), that 10.5 in our previous example would be returned as .105 (i.e. the
  # numeric value divided by 100).
  #
  def self.numeric_rate_value text_rate_value, express_as_decimal:false
    numeric_component = text_rate_value.to_s.match(/(?<percent>\d*[.]?\d*)%/).try(:[], :percent)
    # See if the rate is actually free
    if numeric_component.nil? && text_rate_value.to_s.strip.match(/^Free$/i)
      return BigDecimal("0")
    end

    bd = BigDecimal(numeric_component) rescue nil
    if bd && express_as_decimal
      bd = bd / BigDecimal(100)
    end
    bd
  end

  private
    def update_cache
      CACHE.set "OfficialTariff:ct:#{self.hts_code.strip}:#{self.country_id}", self
    end

    def six_digit_hts
      self.hts_code.length > 6 ? self.hts_code[0, 6] : self.hts_code
    end

    def set_common_rate
      if self.country_id
        country = Country.find_cached_by_id self.country_id
        if ['CA', 'CN', 'PA'].include? country.iso_code
          self.common_rate = self.most_favored_nation_rate
        elsif country.european_union?
          self.common_rate = self.erga_omnes_rate
        else
          self.common_rate = self.general_rate
        end
        if !self.common_rate.blank?
          if self.common_rate.gsub(/\%/, '').strip.match(/^\d+\.?\d*$/)
            self.common_rate_decimal = BigDecimal(self.common_rate.gsub(/\%/, '').strip, 4)/100
          elsif self.common_rate.match(/^Free$/)
            self.common_rate_decimal = 0
          end
        end
      end
    end

    def set_special_rate_key
      if !self.special_rates.blank?
        self.special_rate_key = Digest::MD5.hexdigest(self.special_rates)
      else
        self.special_rate_key = nil
      end
    end

end
