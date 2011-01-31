class Classification < ActiveRecord::Base
  include CustomFieldSupport
  
  belongs_to :product
  belongs_to :country
  
  validates :country_id, :uniqueness => {:scope => :product_id}
  
  has_many :tariff_records, :dependent => :destroy 
   
  accepts_nested_attributes_for :tariff_records, :allow_destroy => true, 
    :reject_if => lambda { |a| a[:hts_1].blank? }
    
end
