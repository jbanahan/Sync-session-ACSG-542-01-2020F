class CustomValue < ActiveRecord::Base
  belongs_to :custom_definition
  belongs_to :customizable, :polymorphic => true
  validates  :custom_definition, :presence => true
  validates  :customizable_id, :presence => true
  validates  :customizable_type, :presence => true
  validate   :validate_unique_record_per_object_and_definition
  after_commit :set_cache
  after_find :set_cache
  
  def self.cached_find_unique custom_definition_id, customizable
    c = CACHE.get unique_cache_key(custom_definition_id, customizable.id, customizable.class)
    if c.nil?
      c = customizable.custom_values.where(:custom_definition_id=>custom_definition_id).first
      c.set_cache unless c.nil?
    end
    return c
  end

  def value
    d = self.custom_definition
    raise "Cannot get custom value without a custom definition" if d.nil?
    self.send "#{d.data_type}_value"
  end

  def value=(val)
    d = self.custom_definition
    raise "Cannot set custom value without a custom definition" if d.nil?
    self.send "#{d.data_type}_value=", val
  end
  
  def set_cache
    if !self.id.nil? && !self.custom_definition_id.nil? && (!self.customizable_id.nil? && !self.customizable_type.nil?)
      to_set = self.destroyed? ? nil : self
      CACHE.set CustomValue.unique_cache_key(self.custom_definition_id,self.customizable_id,self.customizable_type), to_set unless self.id.nil?
    end
  end
  private
  def validate_unique_record_per_object_and_definition
    found = CustomValue.where(:customizable_id => self.customizable_id,
      :customizable_type => self.customizable_type,
      :custom_definition_id => self.custom_definition_id).first
    if !found.nil? && self.id != found.id
      self.errors[:base] << "A field value is already associated with #{@customizable_type}: #{@customizable_id} for field with definition id: #{@custom_definition_id}"
    end 
  end

  def self.unique_cache_key custom_definition_id, customizable_id, customizable_type
    "custom_values:u_c_k:#{custom_definition_id}:#{customizable_id}:#{customizable_type}"
  end
end
