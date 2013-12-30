class Classification < ActiveRecord::Base
  include CustomFieldSupport
  include ShallowMerger
  include TouchesParentsChangedAt
  
  belongs_to :product
  belongs_to :country
  belongs_to :instant_classification
  
  validate :one_classification_per_country_product
  validate :unique_line_numbers_for_tariffs
  validates :country_id, :presence => true

  scope :sort_classification_rank, joins(:country).order("ifnull(countries.classification_rank,9999) ASC, countries.name ASC")
  
  has_many :tariff_records, :dependent => :destroy, :before_add => :set_nested
   
  accepts_nested_attributes_for :tariff_records, :allow_destroy => true, 
    :reject_if => lambda { |a| 
      # Reject if all attributes are blank and _destroy is false
      values = [:hts_1, :hts_2, :hts_3, :schedule_b_1, :schedule_b_2, :schedule_b_3].collect {|k| a[k].blank?}.uniq
      (values.length < 2 && values[0] == true) && (a[:_destroy].blank? || a[:_destroy]=="false")
    }
  dont_shallow_merge :Classification, ['id','created_at','updated_at','country_id','product_id','instant_classification_id']
    
  def find_same
    r = Classification.where(:product_id=>self.product_id).where(:country_id=>self.country_id).where("instant_classification_id is null")
    raise "Multiple Classifications found for product #{self.product_id} and country #{self.country_id}" if r.size > 1
    return r.empty? || r.first.id == self.id ? nil : r.first    
  end

  #has at least one tariff record with an hts number in hts_1
  def classified?
    self.tariff_records.each {|tr| return true unless tr.hts_1.blank?}
    false
  end

  private
  def set_nested tr #needed to support the auto_set_line_number in TariffRecord on a nested form create
    tr.classification ||= self
  end

  def one_classification_per_country_product
    return unless self.product_id
    found = Classification.where(:country_id=>self.country_id,:product_id=>self.product_id)
    return if found.empty? || (found.size==1 && found.first.id==self.id)
    self.errors[:base] << "Each product can only have one classification for each country. (#{self.country.name})"
  end

  #validate this here instead of at the tariff level to handle nested attributes
  #https://rails.lighthouseapp.com/projects/8994/tickets/2160-nested_attributes-validates_uniqueness_of-fails
  def unique_line_numbers_for_tariffs
    max_line_number = 0
    used_line_numbers = []
    self.tariff_records.each do |tr|
      next if tr.marked_for_destruction? || tr.destroyed?
      tr.line_number = max_line_number +1 if tr.line_number.nil?
      self.errors.add(:base,"Line number #{tr.line_number} cannot be used more than once.") if used_line_numbers.include?(tr.line_number)
      used_line_numbers << tr.line_number
      max_line_number = used_line_numbers.sort.last
    end
  end
end
