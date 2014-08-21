class CustomDefinition < ActiveRecord::Base
  validates  :label, :presence => true
  validates  :data_type, :presence => true
  validates  :module_type, :presence => true
  
  has_many   :custom_values, :dependent => :destroy
  has_many   :sort_criterions, :dependent => :destroy
  has_many   :search_criterions, :dependent => :destroy
  has_many   :search_columns, :dependent => :destroy
  has_many   :field_validator_rules, :dependent => :destroy
  has_many   :milestone_definitions, :dependent => :destroy
  
  after_save :reset_cache
  after_save :reset_model_field_constants 
  after_save :reset_field_label
  after_find :set_cache

  def self.cached_find id
    o = nil
    begin
      o = CACHE.get "CustomDefinition:id:#{id}"
    rescue
      $!.log_me ["Exception rescued, you don't need to contact the user."]
    end
    if o.nil?
      o = find id
    end
    o
  end
  
  #returns an Array of custom definitions for the module, sorted by rank then label
  #Note: Internally this calls .all on the result from the DB, so are getting back a real array, not an ActiveRecord result.
  def self.cached_find_by_module_type module_type
    begin
      o = CACHE.get "CustomDefinition:module_type:#{module_type}"
      if o.nil?
        o = CustomDefinition.where(:module_type => module_type).order("rank ASC, label ASC").all
        CACHE.set "CustomDefinition:module_type:#{module_type}", o
      end
      return o.clone
    rescue
      $!.log_me ["Exception rescued, you don't need to contact the user."]
      return CustomDefinition.where(:module_type=>module_type).order("rank ASC, label ASC").all
    end
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
    @@already_set ||= {}
    to_set = self.destroyed? ? nil : self
    if to_set && @@already_set[self.id] != self.updated_at
      CACHE.set "CustomDefinition:id:#{self.id}", to_set unless self.id.nil?
      @@already_set[self.id] = self.updated_at
    end
  end

  def reset_cache
    CACHE.delete "CustomDefinition:id:#{self.id}" unless self.id.nil?
    CACHE.delete "CustomDefinition:module_type:#{self.module_type}" unless self.module_type.nil?
    set_cache
    ModelField.reload true
  end
  private
  def reset_model_field_constants
    ModelField.reset_custom_fields true #reset flag in cached to make sure other passenger instances reload themselves
  end

  def reset_field_label
    FieldLabel.set_label "*cf_#{self.id}", self.label
  end


end
