class FieldValidatorRule < ActiveRecord::Base
  include HoldsCustomDefinition
  before_validation :set_module_type, on: :create
  after_save :reset_model_fields
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
  #Method returns empty array if validation passes, else, a message indicating the reason for failure
  #Passing nested=true will prepend the error messages with the CoreModule name
  def validate_field(base_object,nested=false)
    return [] if self.disabled?
    mf = model_field
    raise "Validation Error: Model field not set for FieldValidatorRule #{self.id}." if mf.blank?
    _validate_input(mf, mf.process_export(base_object, nil, true), nested)
  end

  def validate_input(input,nested=false)
    return [] if self.disabled?
    mf = model_field
    raise "Validation Error: Model field not set for FieldValidatorRule #{self.id}." if mf.blank?
    _validate_input(mf, input, nested)
  end

  def _validate_input(model_field, input, nested)
    r = []
    if self.required? && input.blank?
      r << error_message("#{model_field.label} is required.")
    end
    if !input.blank? #put all checks here
      r += validate_regex input, model_field, nested
      r += validate_greater_than input, model_field, nested
      r += validate_less_than input, model_field, nested
      r += validate_less_than_date input, model_field, nested
      r += validate_greater_than_date input, model_field, nested
      r += validate_more_than_ago input, model_field, nested
      r += validate_less_than_from_now input, model_field, nested
      r += validate_starts_with input, model_field, nested
      r += validate_ends_with input, model_field, nested
      r += validate_contains input, model_field, nested
      r += validate_one_of input, model_field, nested
      r += validate_minimum_length input, model_field, nested
      r += validate_maximum_length input, model_field, nested
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

  def view_groups
    # Need to do this because rules are loaded via migrations (which may be running to add the group)
    if respond_to?(:can_view_groups)
      can_view_groups.to_s.lines.collect{|ln| ln.strip}.sort
    else
      []
    end
  end

  def edit_groups
    # Need to do this because rules are loaded via migrations (which may be running to add the group)
    if respond_to?(:can_edit_groups)
      can_edit_groups.to_s.lines.collect{|ln| ln.strip}.sort
    else
      []
    end
  end

  private
  def update_cache
    FieldValidatorRule.write_module_cache CoreModule.find_by_class_name self.module_type
    FieldValidatorRule.write_field_cache self.model_field_uid
  end
  def validate_regex val, model_field, nested
    generic_validate model_field, nested, val, self.regex,"#{model_field.label} must match expression #{self.regex}.", lambda {val.to_s.match(self.regex)}
  end
  def validate_greater_than val, model_field, nested
    generic_validate model_field, nested, val, self.greater_than, "#{model_field.label} must be greater than #{self.greater_than}.", lambda {val>self.greater_than}
  end
  def validate_less_than val, model_field, nested
    generic_validate model_field, nested, val, self.less_than, "#{model_field.label} must be less than #{self.less_than}.", lambda {val<self.less_than}
  end
  def validate_less_than_date val, model_field, nested
    generic_validate model_field, nested, val, self.less_than_date, "#{model_field.label} must be before #{self.less_than_date}.", lambda {val<self.less_than_date}
  end
  def validate_greater_than_date val, model_field, nested
    generic_validate model_field, nested, val, self.greater_than_date, "#{model_field.label} must be after #{self.greater_than_date}.", lambda {val>self.greater_than_date}
  end
  def validate_more_than_ago val, model_field, nested
    generic_validate model_field, nested, val, self.more_than_ago, "#{model_field.label} must be before #{self.more_than_ago} #{self.more_than_ago_uom} ago.", lambda {val.to_date<(eval "#{self.more_than_ago}.#{self.more_than_ago_uom}.ago.to_date")}
  end
  def validate_less_than_from_now val, model_field, nested
    generic_validate model_field, nested, val, self.less_than_from_now, "#{model_field.label} must be before #{self.less_than_from_now} #{self.less_than_from_now_uom} from now.", lambda {val.to_date<(eval "#{self.less_than_from_now}.#{self.less_than_from_now_uom}.from_now.to_date")}
  end
  def validate_starts_with val, model_field, nested
    generic_validate model_field, nested, val, self.starts_with, "#{model_field.label} must start with #{self.starts_with}.", lambda {val.downcase.starts_with? self.starts_with.downcase}
  end
  def validate_ends_with val, model_field, nested
    generic_validate model_field, nested, val, self.ends_with, "#{model_field.label} must end with #{self.ends_with}.", lambda {val.downcase.ends_with? self.ends_with.downcase}
  end
  def validate_contains val, model_field, nested
    generic_validate model_field, nested, val, self.contains, "#{model_field.label} must contain #{self.contains}.", lambda {!val.downcase.index(self.contains.downcase).nil?}
  end
  def validate_minimum_length val, model_field, nested
    generic_validate model_field, nested, val, self.minimum_length, "#{model_field.label} must be at least #{self.minimum_length} characters.", lambda {val.strip.length>=self.minimum_length}
  end
  def validate_maximum_length val, model_field, nested
    generic_validate model_field, nested, val, self.maximum_length, "#{model_field.label} must be at most #{self.maximum_length} characters.", lambda {val.strip.length<=self.maximum_length}
  end
  def validate_one_of val, model_field, nested
    return [] if self.one_of.blank?
    good_vals = self.one_of_array
    test_vals = good_vals.collect {|v| v.downcase} #remove whitespace and make lowercase
    return [error_message(model_field, nested, "#{model_field.label} must be one of: #{good_vals.join(", ")}.")] unless test_vals.include? val.to_s.strip.downcase
    return []
  end

  def generic_validate model_field, nested, val, comparison_value, message, test_pass
    return [] if comparison_value.blank?
    return [error_message(model_field, nested, message)] unless test_pass.call
    return []
  end

  def set_module_type
    # The module type (just like the uid) will never change...so we only have to set it once
    if self.module_type.blank? && self.model_field_uid
      mf = model_field
      self.module_type = mf.core_module.class_name unless mf.nil?
    end
  end

  #generates the appropriate error message for the validation failure.
  #this will return the message you pass in unless the user has set a custom message
  def error_message model_field, nested, base_message
    m = self.custom_message.blank? ? base_message : self.custom_message
    m = "#{model_field.core_module.label}: #{m}" if nested
    m
  end

  def reset_model_fields
    ModelField.reload true #true resets cache
  end
end
