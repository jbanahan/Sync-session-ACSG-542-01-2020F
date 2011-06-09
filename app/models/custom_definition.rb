class CustomDefinition < ActiveRecord::Base
  validates  :label, :presence => true
  validates  :data_type, :presence => true
  validates  :module_type, :presence => true
  
  has_many   :custom_values, :dependent => :destroy
  has_many   :sort_criterions, :dependent => :destroy
  has_many   :search_criterions, :dependent => :destroy
  has_many   :search_columns, :dependent => :destroy
  has_many   :field_validator_rules, :dependent => :destroy
  
  after_save :reset_model_field_constants 
  after_save :reset_field_label
  after_commit :reset_cache
  after_find :set_cache

  def self.cached_find id
    o = CACHE.get "CustomDefinition:id:#{id}"
    if o.nil?
      o = find id
    end
    o
  end

  def self.cached_find_by_module_type module_type
    o = CACHE.get "CustomDefinition:module_type:#{module_type}"
    if o.nil?
      o = CustomDefinition.where(:module_type => module_type)
      CACHE.set "CustomDefinition:module_type:#{module_type}", o
    end
    o
  end

  def model_field_uid
    self.id.nil? ? nil : "*cf_#{id}"
  end

  def model_field
    mu = model_field_uid
    mu.nil? ? nil : ModelField.find_by_uid(mu)
  end

  def date?
    (!self.data_type.nil?) && self.data_type=="date"
  end
  
  def data_column
    "#{self.data_type}_value"
  end
  
  def can_edit?(user)
    user.company.master?
  end
  
  def can_view?(user)
    user.company.master?
  end
  
  def locked?
    false
  end
  
  DATA_TYPE_LABELS = {
    :text => "Text - Long", 
    :string => "Text",
    :date => "Date",
    :boolean => "Checkbox",
    :decimal => "Decimal",
    :integer => "Integer"
  }
  
  def set_cache
    to_set = self.destroyed? ? nil : self
    CACHE.set "CustomDefinition:id:#{self.id}", to_set unless self.id.nil?
  end

  def reset_cache
    CACHE.delete "CustomDefinition:id:#{self.id}" unless self.id.nil?
    CACHE.delete "CustomDefinition:module_type:#{self.module_type}" unless self.module_type.nil?
    set_cache
  end
  private
  def reset_model_field_constants
    ModelField.reset_custom_fields true #reset flag in cached to make sure other passenger instances reload themselves
  end

  def reset_field_label
    FieldLabel.set_label "*cf_#{self.id}", self.label
  end


end
