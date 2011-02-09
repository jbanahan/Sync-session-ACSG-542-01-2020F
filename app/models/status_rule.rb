class StatusRule < ActiveRecord::Base
  has_many :search_criterions, :dependent => :destroy
  
  #module links (NEVER MAKE THESE :dependent => :destroy)
  has_many :products
  
  validates :module_type, :presence => true
  validates :name, :presence => true
  validates :test_rank, :presence => true
  validates_uniqueness_of :name, :scope => :module_type
  validates_uniqueness_of :test_rank, :scope => :module_type
  
  accepts_nested_attributes_for :search_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| 
      r_val = false
      [:model_field_uid,:operator,:value].each { |f|
        r_val = true if a[f].blank?
      } 
      r_val
  }
  
  def locked?
    false
  end
end
