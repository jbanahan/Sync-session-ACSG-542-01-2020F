# == Schema Information
#
# Table name: field_validator_rules
#
#  id                     :integer          not null, primary key
#  model_field_uid        :string(255)
#  module_type            :string(255)
#  greater_than           :decimal(13, 4)
#  less_than              :decimal(13, 4)
#  more_than_ago          :integer
#  less_than_from_now     :integer
#  more_than_ago_uom      :string(255)
#  less_than_from_now_uom :string(255)
#  greater_than_date      :date
#  less_than_date         :date
#  regex                  :string(255)
#  comment                :text
#  custom_message         :string(255)
#  required               :boolean
#  starts_with            :string(255)
#  ends_with              :string(255)
#  contains               :string(255)
#  one_of                 :text
#  minimum_length         :integer
#  maximum_length         :integer
#  created_at             :datetime
#  updated_at             :datetime
#  custom_definition_id   :integer
#  read_only              :boolean
#  disabled               :boolean
#  can_edit_groups        :text
#  can_view_groups        :text
#  xml_tag_name           :string(255)
#  mass_edit              :boolean
#  can_mass_edit_groups   :text
#  allow_everyone_to_view :boolean
#
# Indexes
#
#  index_field_validator_rules_on_cust_def_id_and_model_field_uid  (custom_definition_id,model_field_uid) UNIQUE
#  index_field_validator_rules_on_model_field_uid                  (model_field_uid) UNIQUE
#

class FieldValidatorRule < ActiveRecord::Base
  include HoldsCustomDefinition
  before_validation :set_module_type, on: :create
  if Rails.env=='test'
    # needs to fire on save to make test cases work because they run inside transactions
    after_save :update_cache
  else
    after_commit :update_cache
  end
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

  def requires_remote_validation?
    [required?, greater_than, less_than, more_than_ago, less_than_from_now, greater_than_date, 
      less_than_date, regex, starts_with, ends_with, contains, one_of, minimum_length, maximum_length].any? {|v| !v.blank? }
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
      r << error_message(model_field,nested,"#{model_field.label} is required.")
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

  def mass_edit_groups
    if respond_to?(:can_mass_edit_groups)
      can_mass_edit_groups.to_s.lines.collect { |ln| ln.strip }.sort
    else
      []
    end
  end

  def string_hsh
    out = {}
    #general
    out[:comment] = "Comment: #{comment}" unless comment.blank?
    out[:custom_message] = "Custom Error Message: #{custom_message}" unless custom_message.blank?
    out[:xml_tag_name] = "Custom XML Tag: #{xml_tag_name}" unless xml_tag_name.blank?
    out[:read_only] = "Read Only: #{read_only}" unless read_only.blank?
    out[:required] = "Required: #{required}" unless required.blank?
    out[:disabled] = "Disabled For All Users: #{disabled}" unless disabled.blank?
    out[:allow_everyone_to_view] = "Allow Everyone To View: #{allow_everyone_to_view}" unless allow_everyone_to_view.blank?
    out[:can_view_groups] = "Groups That Can View Field: #{can_view_groups.gsub(/\n/, ", ")}" unless can_view_groups.blank?
    out[:can_edit_groups] = "Groups That Can Edit Field: #{can_edit_groups.gsub(/\n/, ", ")}" unless can_edit_groups.blank?
    out[:can_mass_edit_groups] = "Groups That Can Mass Edit Field: #{can_mass_edit_groups.gsub(/\n/, ", ")}" unless can_mass_edit_groups.blank?
    #decimal/integer
    out[:greater_than] = "Greater Than #{greater_than}" unless greater_than.blank?
    out[:less_than] = "Less Than #{less_than}" unless less_than.blank?
    #date/datetime
    out[:more_than_ago] = "More Than #{more_than_ago} #{more_than_ago != 1 ? more_than_ago_uom.pluralize : more_than_ago_uom} ago" unless more_than_ago.blank?
    out[:less_than_from_now] = "Less Than #{less_than_from_now} #{less_than_from_now != 1 ? less_than_from_now_uom.pluralize : less_than_from_now_uom} from now" unless less_than_from_now.blank?
    out[:greater_than_date] = "After #{greater_than_date.to_s}" unless greater_than_date.blank?
    out[:less_than_date] = "Before #{less_than_date.to_s}" unless less_than_date.blank?
    #string/text
    out[:minimum_length] = "Minimum Length: #{minimum_length}" unless minimum_length.blank?
    out[:maximum_length] = "Maximum Length: #{maximum_length}" unless maximum_length.blank?
    out[:starts_with] = "Starts With '#{starts_with}'" unless starts_with.blank?
    out[:ends_with] = "Ends With '#{ends_with}'" unless ends_with.blank?
    out[:contains] = "Contains '#{contains}'" unless contains.blank?
    out[:one_of] = "Is One Of: #{one_of.gsub(/\n/, ", ")}" unless one_of.blank?
    out[:mass_edit] = "Mass Editable" unless mass_edit.blank?

    out
  end

  private
  def update_cache
    FieldValidatorRule.write_module_cache CoreModule.find_by_class_name self.module_type
    FieldValidatorRule.write_field_cache self.model_field_uid
    reset_model_fields
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
