# == Schema Information
#
# Table name: custom_definitions
#
#  cdef_uid             :string(255)
#  created_at           :datetime         not null
#  data_type            :string(255)
#  default_value        :string(255)
#  definition           :text(65535)
#  id                   :integer          not null, primary key
#  is_address           :boolean
#  is_user              :boolean
#  label                :string(255)
#  module_type          :string(255)
#  quick_searchable     :boolean
#  rank                 :integer
#  tool_tip             :string(255)
#  updated_at           :datetime         not null
#  virtual_search_query :text(65535)
#  virtual_value_query  :text(65535)
#
# Indexes
#
#  index_custom_definitions_on_cdef_uid     (cdef_uid) UNIQUE
#  index_custom_definitions_on_module_type  (module_type)
#

class CustomDefinition < ActiveRecord::Base
  attr_accessible :cdef_uid, :data_type, :default_value, :definition,
    :is_address, :is_user, :label, :module_type, :quick_searchable, :rank,
    :tool_tip, :virtual_search_query, :virtual_value_query

  cattr_accessor :skip_reload_trigger

  validates  :label, :presence => true
  validates  :data_type, :presence => true
  validates  :module_type, :presence => true
  # Because cdef_uid was added long after custom definitions existed, there's live custom definitions without cdef_uids, so we're going
  # to prevent new ones from being made, but we will continue to allow old ones to be saved.  The screen now generates a default cdef_uid
  # on creation, so all new ones will have cdef_uids
  validates  :cdef_uid, presence: :true, on: :create
  validate :validate_virtual_fields

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

  # returns an Array of custom definitions for the module, sorted by rank then label
  # Note: Internally this calls .all on the result from the DB, so are getting back a real array, not an ActiveRecord result.
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
    ActiveRecord::Base.connection.quote_column_name("#{self.data_type}_value")
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
  }.freeze

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

  def virtual_field?
    self.virtual_value_query.present? || self.virtual_search_query.present?
  end

  # This method generates a query suitable to be used in a SQL FROM or WHERE clause.
  def qualified_field_name
    if self.virtual_search_query.blank?
      generate_qualified_field_query
    else
      # NOTE: We COULD enforce the datatype by wrapping the virtual search query in a cast...
      "(#{self.virtual_search_query})"
    end
  end

  # This method utilizes the virtual value query (injecting the customizable_id given) and returns the virtual value
  # the query finds.  NOTE: A LIMIT 1 is added to all queries.  This method is meant to return a single value
  # for a specific "parent" object.
  def virtual_value customizable
    return nil if self.virtual_value_query.blank?

    interpolated_query = parameterize_query(self.virtual_value_query, { customizable_id: customizable.id }) +  " LIMIT 1"

    self.class.connection.execute(interpolated_query).first.try(:first)
  end

  def self.generate_cdef_uid custom_definition
    core_module = custom_definition.core_module
    return nil if core_module.nil?

    prefix = CoreModule.module_abbreviation core_module
    uid = custom_definition.label.to_s.gsub(/\W/, "_").gsub(/^_+/, "").gsub(/_+$/, "").underscore
    "#{prefix}_#{uid}".squeeze("_")
  end

  private

    def generate_qualified_field_query
      column = data_column
      table = ActiveRecord::Base.connection.quote_table_name core_module.table_name
      "(SELECT #{column} FROM custom_values WHERE customizable_id = #{table}.id AND #{ActiveRecord::Base.sanitize_sql_array(["custom_definition_id = ? AND customizable_type = ?", self.id, self.module_type])})"
    end

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

    def parameterize_query query, replacements
      # I would MUCH rather utilize Rail's built in methods for query parameterization, but I'm having issues with it because
      # of specialized queries that contain %'s in them (ie for date formatting in Mysql) and rails/ruby raising ArgumentError: malformed format string due to them
      # ..ergo, we'er just going to do this with simple regexes to work like standard ruby string interpolation
      replacements.each_pair do |key, value|
        if value.is_a?(String)
          value = self.class.connection.quote(value)
        end

        regexp = Regexp.new(('#{\s*' + "#{key}" + '\s*}'))

        # Do NOT do gsub! here...the query value passed in is likely the acutal virtual_value_query attribute and we don't
        # want to change that value in place, otherwise every lookup will use the same id we gsub into place.
        query = query.gsub(regexp, value.to_s)
      end
      query
    end

    def validate_virtual_fields
      errors.add(:virtual_search_query, "cannot be blank if Virtual value query is present.") if self.virtual_search_query.blank? && !self.virtual_value_query.blank?
      errors.add(:virtual_value_query, "cannot be blank if Virtual search query is present.") if self.virtual_value_query.blank? && !self.virtual_search_query.blank?
    end
end
