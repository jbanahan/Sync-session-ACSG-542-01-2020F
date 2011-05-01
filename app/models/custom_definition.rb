class CustomDefinition < ActiveRecord::Base
  validates  :label, :presence => true
  validates  :data_type, :presence => true
  validates  :module_type, :presence => true
  
  has_many   :custom_values, :dependent => :destroy
  has_many   :sort_criterions, :dependent => :destroy
  has_many   :search_criterions, :dependent => :destroy
  has_many   :search_columns, :dependent => :destroy
  
  after_save :reset_model_field_constants 
  after_save :reset_field_label
  after_commit :set_cache
  after_find :set_cache

  def self.cached_find id
    o = CACHE.get "custom_definition-#{id}"
    if o.nil?
      o = find id
    end
    o
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
    CACHE.set "#{self.class.to_s.tableize}-#{self.id}", to_set unless self.id.nil?
  end
  private
  def reset_model_field_constants
    ModelField.reset_custom_fields
  end

  def reset_field_label
    FieldLabel.set_label "*cf_#{self.id}", self.label
  end


end
