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
end
