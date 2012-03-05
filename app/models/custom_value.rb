class CustomValue < ActiveRecord::Base
  include TouchesParentsChangedAt
  
  belongs_to :custom_definition
  belongs_to :customizable, :polymorphic => true
  validates  :custom_definition, :presence => true
  validates  :customizable_id, :presence => true
  validates  :customizable_type, :presence => true
  after_commit :set_cache
  after_find :set_cache
  
  default_scope includes(:custom_definition)

  def self.cached_find_unique custom_definition_id, customizable
    #c = CACHE.get unique_cache_key(custom_definition_id, customizable.id, customizable.class)
    #if c.nil?
      c = customizable.custom_values.where(:custom_definition_id=>custom_definition_id).first
     # c.set_cache unless c.nil?
    #end
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
    v = [:date,:datetime].include?(d.data_type) ? parse_date(val) : val
    self.send "#{d.data_type}_value=", v
  end
  
  def set_cache
=begin
    if !self.id.nil? && !self.custom_definition_id.nil? && (!self.customizable_id.nil? && !self.customizable_type.nil?)
      to_set = self.destroyed? ? nil : self
      CACHE.set CustomValue.unique_cache_key(self.custom_definition_id,self.customizable_id,self.customizable_type), to_set unless self.id.nil?
    end
=end
  end

  def touch_parents_changed_at #overriden to find core module differently
    ct = self.customizable_type
    unless ct.nil?
      cm = CoreModule.find_by_class_name ct
      cm.touch_parents_changed_at self.customizable unless cm.nil?
    end
  end


  private
  def self.unique_cache_key custom_definition_id, customizable_id, customizable_type
    "CustomValue:u_c_k:#{custom_definition_id}:#{customizable_id}:#{customizable_type}"
  end
  def parse_date d
    return d unless d.is_a?(String)
    if /^[0-9]{2}\/[0-9]{2}\/[0-9]{4}$/.match(d)
      return Date.new(d[6,4].to_i,d[0,2].to_i,d[3,2].to_i)
    elsif /^[0-9]{2}-[0-9]{2}-[0-9]{4}$/.match(d)
      return Date.new(d[6,4].to_i,d[3,2].to_i,d[0,2].to_i)
    else
      return d
    end
  end
end
