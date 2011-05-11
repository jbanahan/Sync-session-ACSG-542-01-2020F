class FieldValidatorRule < ActiveRecord::Base
  include HoldsCustomDefinition
  before_validation :set_module_type
  after_commit :update_cache
  validates :model_field_uid, :presence=>true, :uniqueness => true
  validates :module_type, :presence=>true

  #finds all rules for the given core_module, using the cache if loaded
  def self.find_cached_by_core_module core_module
    r = CACHE.get "FieldValidatorRule:module:#{core_module.class_name}"
    r = write_module_cache core_module if r.nil?
    r.nil? ? [] : r
  end

  #finds all rules for the given model_field_uid, using the cache if loaded
  def self.find_cached_by_model_field_uid model_field_uid
    r = CACHE.get "FieldValidatorRule:field:#{model_field_uid}"
    r = write_field_cache model_field_uid if r.nil?
    r.nil? ? [] : r
  end

  #validates the given base object based on the rules definied in the FieldValidatorRule instance.
  #The base_object should be an instance of the class backing the CoreModule set in the field validator
  #For example, if the FieldValidator's module_type is Product, then you should pass in a Product object
  #Method returns nil if validation passes, else, a message indicating the reason for failure
  #Passing nested=true will prepend the error messages with the CoreModule name
  def validate_field(base_object,nested=false)
    @mf = model_field
    raise "Validation Error: Model field not set for FieldValidatorRule #{self.id}." if @mf.nil?
    validate_input @mf.process_export(base_object), nested
  end

  def validate_input(input,nested=false)
    raise "Validation Error: Model field not set for FieldValidatorRule #{self.id}." if model_field.nil?
    @nested = nested
    @mf = model_field 
    r = []
    if self.required? && input.blank?
      r << error_message("#{@mf.label} is required.")
    end
    r += validate_regex input
    Set.new(r).to_a
  end

  def required? 
    self.required 
  end

  def model_field
    ModelField.find_by_uid self.model_field_uid unless self.model_field_uid.blank?
  end

  def self.write_module_cache core_module
    r = FieldValidatorRule.where(:module_type=>core_module.class_name).to_a
    CACHE.set "FieldValidatorRule:module:#{core_module.class_name}", r
    r
  end
  def self.write_field_cache model_field_uid
    r = FieldValidatorRule.where(:model_field_uid=>model_field_uid).to_a
    CACHE.set "FieldValidatorRule:field:#{model_field_uid}", r
    r
  end
  private
  def update_cache
    FieldValidatorRule.write_module_cache CoreModule.find_by_class_name self.module_type
    FieldValidatorRule.write_field_cache self.model_field_uid
  end
  def validate_regex val
    return [] if self.regex.blank?
    return [] if val.blank? && !self.required?
    return [error_message("#{@mf.label} must match expression #{self.regex}.")] unless val.to_s.match self.regex
    return []
  end

  def set_module_type
    if self.model_field_uid
      mf = model_field
      self.module_type = mf.core_module.class_name unless mf.nil?
    end
  end

  #generates the appropriate error message for the validation failure.
  #this will return the message you pass in unless the user has set a custom message
  def error_message base_message
    m = self.custom_message.blank? ? base_message : self.custom_message
    m = "#{@mf.core_module.label}: #{m}" if @nested
    m
  end
end
