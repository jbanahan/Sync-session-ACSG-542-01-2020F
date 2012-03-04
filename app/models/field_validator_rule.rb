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

  #validates the given base object based on the rules defined in the FieldValidatorRule instance.
  #The base_object should be an instance of the class backing the CoreModule set in the field validator
  #For example, if the FieldValidator's module_type is Product, then you should pass in a Product object
  #Method returns nil if validation passes, else, a message indicating the reason for failure
  #Passing nested=true will prepend the error messages with the CoreModule name
  def validate_field(base_object,nested=false)
    @mf = model_field
    raise "Validation Error: Model field not set for FieldValidatorRule #{self.id}." if @mf.nil?
    validate_input @mf.process_export(base_object,nil,true), nested
  end

  def validate_input(input,nested=false)
    raise "Validation Error: Model field not set for FieldValidatorRule #{self.id}." if model_field.nil?
    @nested = nested
    @mf = model_field 
    r = []
    if self.required? && input.blank?
      r << error_message("#{@mf.label} is required.")
    end
    if !input.blank? #put all checks here
      r += validate_regex input
      r += validate_greater_than input
      r += validate_less_than input
      r += validate_less_than_date input
      r += validate_greater_than_date input
      r += validate_more_than_ago input
      r += validate_less_than_from_now input
      r += validate_starts_with input
      r += validate_ends_with input
      r += validate_contains input
      r += validate_one_of input
      r += validate_minimum_length input
      r += validate_maximum_length input
    end
    Set.new(r).to_a
  end

  #returns the value of the one_of field as an array
  def one_of_array 
    return [] if self.one_of.blank?
    r = self.one_of.split("\n")
    return r.collect {|v| v.strip}
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
    generic_validate val, self.regex,"#{@mf.label} must match expression #{self.regex}.", lambda {val.to_s.match(self.regex)}
  end
  def validate_greater_than val
    generic_validate val, self.greater_than, "#{@mf.label} must be greater than #{self.greater_than}.", lambda {val>self.greater_than}
  end
  def validate_less_than val
    generic_validate val, self.less_than, "#{@mf.label} must be less than #{self.less_than}.", lambda {val<self.less_than}
  end
  def validate_less_than_date val
    generic_validate val, self.less_than_date, "#{@mf.label} must be before #{self.less_than_date}.", lambda {val<self.less_than_date}
  end
  def validate_greater_than_date val
    generic_validate val, self.greater_than_date, "#{@mf.label} must be after #{self.greater_than_date}.", lambda {val>self.greater_than_date}
  end
  def validate_more_than_ago val
    generic_validate val, self.more_than_ago, "#{@mf.label} must be before #{self.more_than_ago} #{self.more_than_ago_uom} ago.", lambda {val.to_date<(eval "#{self.more_than_ago}.#{self.more_than_ago_uom}.ago.to_date")}
  end
  def validate_less_than_from_now val
    generic_validate val, self.less_than_from_now, "#{@mf.label} must be before #{self.less_than_from_now} #{self.less_than_from_now_uom} from now.", lambda {val.to_date<(eval "#{self.less_than_from_now}.#{self.less_than_from_now_uom}.from_now.to_date")}
  end
  def validate_starts_with val
    generic_validate val, self.starts_with, "#{@mf.label} must start with #{self.starts_with}.", lambda {val.downcase.starts_with? self.starts_with.downcase}
  end
  def validate_ends_with val
    generic_validate val, self.ends_with, "#{@mf.label} must end with #{self.ends_with}.", lambda {val.downcase.ends_with? self.ends_with.downcase}
  end
  def validate_contains val
    generic_validate val, self.contains, "#{@mf.label} must contain #{self.contains}.", lambda {!val.downcase.index(self.contains.downcase).nil?}
  end
  def validate_minimum_length val
    generic_validate val, self.minimum_length, "#{@mf.label} must be at least #{self.minimum_length} characters.", lambda {val.strip.length>=self.minimum_length}
  end
  def validate_maximum_length val
    generic_validate val, self.maximum_length, "#{@mf.label} must be at most #{self.maximum_length} characters.", lambda {val.strip.length<=self.maximum_length}
  end
  def validate_one_of val
    return [] if self.one_of.blank?
    good_vals = self.one_of_array 
    test_vals = good_vals.collect {|v| v.downcase} #remove whitespace and make lowercase
    return [error_message("#{@mf.label} must be one of: #{good_vals.join(", ")}.")] unless test_vals.include? val.to_s.strip.downcase
    return []
  end

  def generic_validate val, comparison_value, message, test_pass
    return [] if comparison_value.blank?
    return [error_message(message)] unless test_pass.call
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
