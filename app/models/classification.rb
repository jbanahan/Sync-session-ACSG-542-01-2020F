class Classification < ActiveRecord::Base
  include CustomFieldSupport
  include ShallowMerger
  
  belongs_to :product
  belongs_to :country
  
  validates :country_id, :uniqueness => {:scope => :product_id}
  validates :product, :presence => true
  validates :country_id, :presence => true
  
  has_many :tariff_records, :dependent => :destroy 
   
  accepts_nested_attributes_for :tariff_records, :allow_destroy => true, 
    :reject_if => lambda { |a| a[:hts_1].blank? && (a[:_destroy].blank? || a[:_destroy]=="false")}


  dont_shallow_merge :Classification, ['id','created_at','updated_at','country_id','product_id']
    
  def find_same
    r = Classification.where(:product_id=>self.product_id).where(:country_id=>self.country_id)
    raise "Multiple Classifications found for product #{self.product_id} and country #{self.country_id}" if r.size > 1
    return r.empty? ? nil : r.first    
  end
end
