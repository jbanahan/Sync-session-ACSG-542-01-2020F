# == Schema Information
#
# Table name: tariff_records
#
#  classification_id :integer
#  created_at        :datetime         not null
#  hts_1             :string(255)
#  hts_2             :string(255)
#  hts_3             :string(255)
#  id                :integer          not null, primary key
#  line_number       :integer
#  schedule_b_1      :string(255)
#  schedule_b_2      :string(255)
#  schedule_b_3      :string(255)
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_tariff_records_on_classification_id  (classification_id)
#  index_tariff_records_on_hts_1              (hts_1)
#  index_tariff_records_on_hts_2              (hts_2)
#  index_tariff_records_on_hts_3              (hts_3)
#

class TariffRecord < ActiveRecord::Base
  include ShallowMerger
  include CustomFieldSupport
  include TouchesParentsChangedAt

  #hold arrays of OfficialTariffs for potential matches to be used for this record
  attr_accessor :hts_1_matches, :hts_2_matches, :hts_3_matches, :view_sequence #used to identified records generated from the screen so we can apply custom fields to the right record
  
  attr_accessible :country_id, :country, :product_id, :product,
    :created_at, :updated_at, :instant_classificaiton_id, :hts_1, 
    :hts_2, :hts_3, :line_number

  belongs_to :classification, :touch=>true, :inverse_of=>:tariff_records
  has_one :product, :through=>:classification

  validates :line_number, :uniqueness => {:scope => :classification_id}

  before_validation :auto_set_line_number

  dont_shallow_merge :TariffRecord, ['id','created_at','updated_at','line_number','classification_id']
  
  def hts_1=(str)
    write_attribute(:hts_1, TariffRecord.clean_hts(str))
  end

  def hts_2=(str)
    write_attribute(:hts_2, TariffRecord.clean_hts(str))
  end

  def hts_3=(str)
    write_attribute(:hts_3, TariffRecord.clean_hts(str))
  end

  def schedule_b_1=(str)
    write_attribute(:schedule_b_1, TariffRecord.clean_hts(str))
  end

  def schedule_b_2=(str)
    write_attribute(:schedule_b_2, TariffRecord.clean_hts(str))
  end

  def schedule_b_3=(str)
    write_attribute(:schedule_b_3, TariffRecord.clean_hts(str))
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
  
  #are any of the 3 schedule b code fields populated
  def has_schedule_b?
    !self.schedule_b_1.blank? || 
    !self.schedule_b_2.blank? ||
    !self.schedule_b_3.blank?
  end

  def auto_set_line_number 
    #WARNING: this is used by a migration so it can't go away or be renamed without 
    #editing 20110315202025_add_line_number_to_tariff_record.rb migration
    if self.line_number.nil? || self.line_number < 1
      max = 0
      self.classification.tariff_records.each {|tr| max = tr.line_number unless tr.line_number.nil? || tr.line_number < max}
      self.line_number = (max.nil? || max < 1) ? 1 : (max + 1)
    end
  end 

  def find_same
    r = TariffRecord.where(:classification_id=>self.classification_id).where(:line_number=>self.line_number)
    raise "Multiple Tariff Records found for classification #{self.classification_id} and line number #{self.line_number}" if r.size > 1
    return r.empty? ? nil : r.first
  end

 
  def self.clean_hts(str)
    str.to_s.gsub(/[^0-9A-Za-z]/,'') unless str.nil?
  end

  def self.validate_hts(str) 
    !str.match(/^[0-9A-Za-z\. ]*$/).nil?
  end

  private
  def find_official_tariff hts_number
    OfficialTariff.where(:country_id=>self.classification.country,:hts_code=>hts_number).first unless self.classification.nil? || hts_number.blank?
  end
end
