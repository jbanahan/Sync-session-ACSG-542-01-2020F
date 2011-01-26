class SearchSetup < ActiveRecord::Base
  validates   :name, :presence => true
  validates   :user, :presence => true
  validates   :module_type, :presence => true
  
  has_many :search_criterions, :dependent => :destroy
  has_many :sort_criterions, :dependent => :destroy
  has_many :search_columns, :dependent => :destroy
  
  belongs_to :user
  
  accepts_nested_attributes_for :search_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| 
      r_val = false
      [:model_field_uid,:condition,:value].each { |f|
        r_val = true if a[f].blank?
      } 
      r_val
  }
  accepts_nested_attributes_for :sort_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| !a[:model_field_uid].blank? }
  accepts_nested_attributes_for :search_criterions, :allow_destroy => true,
    :reject_if => lambda { |a| !a[:model_field_uid].blank? }
    
  scope :for_user, lambda {|u| where(:user_id => u)} 
  
  def search
    base = Kernel.const_get(self.module_type)
    self.search_criterions.each do |sc|
      base = sc.apply(base)
    end
    self.sort_criterions.order("rank ASC").each do |sort|
      base = sort.apply(base)
    end
    base
  end
  
  def touch(save_obj=false)
    self.last_accessed = Time.now
    self.save if save_obj 
  end
end
