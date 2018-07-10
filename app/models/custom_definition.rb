# == Schema Information
#
# Table name: custom_definitions
#
#  cdef_uid         :string(255)
#  created_at       :datetime         not null
#  data_type        :string(255)
#  default_value    :string(255)
#  definition       :text
#  id               :integer          not null, primary key
#  is_address       :boolean
#  is_user          :boolean
#  label            :string(255)
#  module_type      :string(255)
#  quick_searchable :boolean
#  rank             :integer
#  tool_tip         :string(255)
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_custom_definitions_on_cdef_uid     (cdef_uid) UNIQUE
#  index_custom_definitions_on_module_type  (module_type)
#

class CustomDefinition < ActiveRecord::Base
  cattr_accessor :skip_reload_trigger

  validates  :label, :presence => true
  validates  :data_type, :presence => true
  validates  :module_type, :presence => true
  # Because cdef_uid was added long after custom definitions existed, there's live custom definitions without cdef_uids, so we're going
  # to prevent new ones from being made, but we will continue to allow old ones to be saved.  The screen now generates a default cdef_uid
  # on creation, so all new ones will have cdef_uids
  validates  :cdef_uid, presence: :true, on: :create

  has_many   :custom_values, :dependent => :destroy
  has_many   :sort_criterions, :dependent => :destroy
  has_many   :search_criterions, :dependent => :destroy
  has_many   :search_columns, :dependent => :destroy
  has_many   :field_validator_rules, :dependent => :destroy
  has_many   :milestone_definitions, :dependent => :destroy

  # This is more here for the hundreds of test cases that don't set cdef_uids than anything
  before_validation :set_cdef_uid, on: :create
  after_save :reset_cache
  after_destroy :reset_cache
  after_destroy :delete_field_label
  after_save :reset_field_label
  after_find :set_cache

  def core_module
    return nil if self.module_type.blank?
    CoreModule.find_by_class_name self.module_type
  end

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
    ModelField.find_by_uid(model_field_uid)
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
    :integer => "Integer",
    :datetime => "Date/Time"
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

    if @@skip_reload_trigger
      # This call is a quick shortcut for our test cases where we don't
      # actually have to reload and recache the whole module field data structures
      # so they can be pushed out to all the running processes.  There's only a single
      # process so, we don't need or want this.  (At the time of writing, this change shaved off ~2 minutes on
      # a full test suite run)
      if self.destroyed?
        ModelField.remove_model_field(core_module, model_field_uid)
      else
        ModelField.add_update_custom_field self
      end
    else
      # Reload and recache the whole model field data structure
      ModelField.reload true
    end
  end

  def self.generate_cdef_uid custom_definition
    core_module = custom_definition.core_module
    return nil if core_module.nil?

    prefix = CoreModule.module_abbreviation core_module
    uid = custom_definition.label.to_s.gsub(/\W/, "_").gsub(/^_+/, "").gsub(/_+$/, "").underscore
    "#{prefix}_#{uid}".squeeze("_")
  end

  private

    def set_cdef_uid
      if self.cdef_uid.blank?
        self.cdef_uid = CustomDefinition.generate_cdef_uid self
      end
    end

    def reset_field_label
      FieldLabel.set_label model_field_uid, self.label
    end

    def delete_field_label
      FieldLabel.where(model_field_uid: model_field_uid).destroy_all
    end

end
