class TariffRecord < ActiveRecord::Base
  include ShallowMerger
  #hold arrays of OfficialTariffs for potential matches to be used for this record
  attr_accessor :hts_1_matches, :hts_2_matches, :hts_3_matches 
  
  belongs_to :classification

  validates :line_number, :uniqueness => {:scope => :classification_id}

  before_validation :auto_set_line_number

  dont_shallow_merge :TariffRecord, ['id','created_at','updated_at','line_number','classification_id']
  
  def hts_1=(str)
    write_attribute(:hts_1, clean_hts(str))
  end

  def hts_2=(str)
    write_attribute(:hts_2, clean_hts(str))
  end

  def hts_3=(str)
    write_attribute(:hts_3, clean_hts(str))
  end

  def hts_1_official_tariff
    find_official_tariff self.hts_1  
  end

  def hts_2_official_tariff
    find_official_tariff self.hts_2
  end

  def hts_3_official_tariff
    find_official_tariff self.hts_3
  end
  
  def auto_set_line_number 
    #WARNING: this is used by a migration so it can't go away or be renamed without 
    #editing 20110315202025_add_line_number_to_tariff_record.rb migration
    if self.line_number.nil? || self.line_number < 1
      max = nil
      max = TariffRecord.where(:classification_id => self.classification_id).maximum(:line_number) unless self.classification_id.nil?
      self.line_number = (max.nil? || max < 1) ? 1 : (max + 1)
    end
  end 

  def find_same
    r = TariffRecord.where(:classification_id=>self.classification_id).where(:line_number=>self.line_number)
    raise "Multiple Tariff Records found for classification #{self.classification_id} and line number #{self.line_number}" if r.size > 1
    return r.empty? ? nil : r.first
  end

  private
  def clean_hts(str)
    str.to_s.gsub(/[^0-9]/,'') unless str.nil?
  end
  def find_official_tariff hts_number
    OfficialTariff.where(:country_id=>self.classification.country,:hts_code=>hts_number).first unless self.classification.nil? || hts_number.blank?
  end
end
