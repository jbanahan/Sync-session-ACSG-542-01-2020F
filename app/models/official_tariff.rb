class OfficialTariff < ActiveRecord::Base
  belongs_to :country
  has_one :official_quota

  validates :country, :presence => true
  validates :hts_code, :presence => true
  validates :full_description, :presence => true
  
  validates :hts_code, :uniqueness => {:scope => :country_id}
  
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

end
