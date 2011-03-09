class SearchSetup < ActiveRecord::Base
  validates   :name, :presence => true
  validates   :user, :presence => true
  validates   :module_type, :presence => true
  
  has_many :search_criterions, :dependent => :destroy
  has_many :sort_criterions, :dependent => :destroy
  has_many :search_columns, :dependent => :destroy
  has_many :search_schedules, :dependent => :destroy
  
  belongs_to :user
  
  accepts_nested_attributes_for :search_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| 
      r_val = false
      [:model_field_uid,:operator,:value].each { |f|
        r_val = true if a[f].blank?
      } 
      r_val
  }
  accepts_nested_attributes_for :sort_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| a[:model_field_uid].blank? }
  accepts_nested_attributes_for :search_columns, :allow_destroy => true,
    :reject_if => lambda { |a| a[:model_field_uid].blank? }
    
  scope :for_user, lambda {|u| where(:user_id => u)} 
  scope :for_module, lambda {|m| where(:module_type => m.class_name)}
  
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

  # Returns a new, saved search setup with the columns passed from the given array
  def self.create_with_columns(model_field_uids,user,name="Default")
    ss = SearchSetup.create(:name=>name,:user => user,:module_type=>ModelField.find_by_uid(model_field_uids[0]).core_module.class_name,
        :simple=>false,:last_accessed=>Time.now)
    model_field_uids.each_with_index do |uid,i|
      ss.search_columns.create(:rank=>i,:model_field_uid=>uid)
    end
    ss
  end
  
  # Returns a copy of the SearchSetup with matching columns, search & sort criterions 
  # all built.
  #
  # If a true parameter is provided, everything in the tree will be saved to the database.
  # 
  # last_accessed is left empty intentionally
  def deep_copy(new_name, save_obj=false) 
    ss = SearchSetup.new(:name => new_name, :module_type => self.module_type, :user => self.user, :simple => self.simple)
    ss.save if save_obj
    self.search_criterions.each do |sc|
      new_sc = ss.search_criterions.build(:operator => sc.operator, :value => sc.value, :milestone_plan_id => sc.milestone_plan_id, 
        :status_rule_id => sc.status_rule_id, :model_field_uid => sc.model_field_uid, :search_setup_id => sc.search_setup_id,
        :custom_definition_id => sc.custom_definition_id
      )
      new_sc.save if save_obj
    end
    self.search_columns.each do |sc|
      new_sc = ss.search_columns.build(:search_setup_id=>sc.search_setup_id, :rank=>sc.rank, 
        :model_field_uid=>sc.model_field_uid, :custom_definition_id=>sc.custom_definition_id
      )
      new_sc.save if save_obj
    end
    self.sort_criterions.each do |sc|
      new_sc = ss.sort_criterions.build(:search_setup_id=>sc.search_setup_id, :rank=>sc.rank,
        :model_field_uid => sc.model_field_uid, :custom_definition_id => sc.custom_definition_id,
        :descending => sc.descending
      )
      new_sc.save if save_obj
    end
    ss
  end
end
