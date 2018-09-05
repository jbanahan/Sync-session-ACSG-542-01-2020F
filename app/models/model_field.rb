require 'open_chain/field_logic'
require 'open_chain/model_field_definition/full_model_field_definition'
require 'open_chain/model_field_generator/full_model_field_generator'
require 'open_chain/model_field_definition/custom_field_support'

# -*- SkipSchemaAnnotations
class ModelField
  extend OpenChain::ModelFieldGenerator::FullModelFieldGenerator
  extend OpenChain::ModelFieldDefinition::FullModelFieldDefinition
  extend OpenChain::ModelFieldDefinition::CustomFieldSupport
  include OpenChain::ModelFieldDefinition

  # When web mode is true, the class assumes that there is a before filter calling ModelField.reload_if_stale at the beginning of every request.
  # This means the class won't call memchached on every call to ModelField.find_by_uid to see if the ModelFieldSetups are stale
  # This should not be used outside of the web environment where jobs will be long running
  cattr_accessor :disable_stale_checks

  # if not empty, used by initializer to figure out the read_only? state
  @@field_validator_rules = HashWithIndifferentAccess.new
  @@public_field_cache = HashWithIndifferentAccess.new
  @@custom_definition_cache = HashWithIndifferentAccess.new
  @@field_label_cache = HashWithIndifferentAccess.new

  @@last_loaded = nil
  attr_reader :model, :field_name, :label_prefix, :sort_rank,
              :import_lambda, :export_lambda,
              :custom_id, :data_type, :core_module,
              :join_statement, :join_alias, :qualified_field_name, :uid,
              :public, :public_searchable, :definition, :disabled, :field_validator_rule,
              :user_accessible, :autocomplete, :required, :cdef_uid

  def initialize(rank, uid, core_module, field_name, options={})
    o = {entity_type_field: false, history_ignore: false, read_only: false, user_accessible: true, restore_field: true}.merge(options)
    @uid = uid
    @core_module = core_module
    @sort_rank = rank
    @model = core_module.class_name.to_sym unless core_module.nil?
    @field_name = field_name
    @definition = o[:definition]
    @import_lambda = o[:import_lambda]
    @export_lambda = o[:export_lambda]
    @can_view_lambda = o[:can_view_lambda]
    @can_edit_lambda = o[:can_edit_lambda]
    if o[:custom_id]
      @custom_id = o[:custom_id]
      self.custom_definition
    elsif o[:custom_definition]
      @custom_id = o[:custom_definition].id
      @custom_definition = o[:custom_definition]
    end

    @join_statement = o[:join_statement]
    @join_alias = o[:join_alias]
    @data_type = o[:data_type].nil? ? determine_data_type : o[:data_type].to_sym
    pf = nil
    if @@public_field_cache.empty?
      pf = PublicField.find_by_model_field_uid @uid
    else
      pf = @@public_field_cache[@uid]
    end
    @public = !pf.nil?
    @public_searchable = @public && pf.searchable
    @qualified_field_name = o[:qualified_field_name]
    @label_override = o[:label_override]
    @entity_type_field = o[:entity_type_field]
    @history_ignore = o[:history_ignore]
    @currency = o[:currency]
    @query_parameter_lambda = o[:query_parameter_lambda]
    @process_query_result_lambda = o[:process_query_result_lambda]
    @field_validator_rule = self.class.field_validator_rule uid
    @field_validator_rule = o[:field_validator_rule] ? o[:field_validator_rule] : @field_validator_rule
    @read_only = o[:read_only] || @field_validator_rule.try(:read_only?)
    @mass_edit = o[:mass_edit] || @field_validator_rule.try(:mass_edit?)

    # The respond_to here is pretty much solely there for the migration case when disabled? didn't
    # exist and the migration is creating it - unfortunately this is necesitated because
    # we have some initializers that reference model fields.
    @disabled = o[:disabled] || (@field_validator_rule.respond_to?(:disabled?) && @field_validator_rule.disabled?)
    @can_view_groups = SortedSet.new(@field_validator_rule.respond_to?(:view_groups) ? @field_validator_rule.view_groups : [])
    @can_edit_groups = SortedSet.new(@field_validator_rule.respond_to?(:edit_groups) ? @field_validator_rule.edit_groups : [])
    @can_mass_edit_groups = SortedSet.new(@field_validator_rule.respond_to?(:mass_edit_groups) ? @field_validator_rule.mass_edit_groups : [])
    # Allow everyone to view exists for the case where you have a field that you want to limit edit access but not view access (the default
    # case prevents any view level access if a edit group exists on the field validator rule)
    @everyone_can_view = @field_validator_rule.respond_to?(:allow_everyone_to_view?) && @field_validator_rule.allow_everyone_to_view?

    if !o[:default_label].blank?
      FieldLabel.set_default_value @uid, o[:default_label]
    end
    @user_accessible = o[:user_accessible]
    @user_field = o[:user_field]
    @user_id_field = o[:user_id_field]
    @user_full_name_field = o[:user_full_name_field]
    @address_field = o[:address_field]
    @address_field_full = o[:address_field_full]
    @address_field_id = o[:address_field_id]
    @select_options_lambda = o[:select_options_lambda]
    @autocomplete = o[:autocomplete]
    @restore_field = o[:restore_field]
    @required = o[:required]
    @search_value_preprocess_lambda = o[:search_value_preprocess_lambda]
    @xml_tag_name = o[:xml_tag_name]
    @cdef_uid = o[:cdef_uid] if self.custom?
    self.base_label #load from cache if available
  rescue => e
    # Re-raise any error here but add a message identifying the field that failed
    raise e.class, "Failed loading uid #{uid}: #{e.message}", e.backtrace
  end

  # do post processing on raw sql query result generated using qualified_field_name
  def process_query_result val, user
    if disabled? || !can_view?(user)
      return nil
    end

    result = @process_query_result_lambda ? @process_query_result_lambda.call(val) : val

    # Make sure all times returned from the database are translated to the user's timezone (or Eastern if user has no timezone)
    if result.respond_to?(:acts_like_time?) && result.acts_like_time?
      result = result.in_time_zone(ActiveSupport::TimeZone[user.try(:time_zone) ? user.time_zone : "Eastern Time (US & Canada)"])
    end

    result
  end

  def custom_definition
    return nil unless self.custom?
    return @custom_definition if @custom_definition

    @custom_definition = @@custom_definition_cache[@uid] unless @custom_definition
    @custom_definition = CustomDefinition.find_by_id @custom_id unless @custom_definition
    @custom_definition
  end

  # if true, then the field can't be updated with `process_import`
  def read_only?
    @read_only
  end

  def mass_edit?
    @mass_edit
  end

  def disabled?
    @disabled
  end

  def user_accessible?
    @user_accessible
  end

  def user_field?
    @user_field
  end

  def user_full_name_field?
    @user_full_name_field
  end

  def user_id_field?
    @user_id_field
  end

  def address_field?
    @address_field == true
  end

  def address_field_full?
    @address_field_full == true
  end

  def address_field_id?
    @address_field_id == true
  end

  def address_field_full?
    @address_field_full
  end

  def restore_field?
    @restore_field
  end

  def required?
    @required
  end

  def self.constant_uid? uid
    uid.to_s.match(/^\*const_/)
  end

  def xml_tag_name
    tag_name = @field_validator_rule && !@field_validator_rule.xml_tag_name.blank? ? @field_validator_rule.xml_tag_name : self.uid
    tag_name.to_s.gsub(/[\W]/,'_')
  end

  def select_options
    return nil unless @select_options_lambda
    @select_options_lambda.call()
  end

  # returns true if the given user should be allowed to mass edit this field
  def can_mass_edit? user
    return false unless mass_edit?
    return false unless user_accessible
    return false unless can_edit?(user)

    in_groups = false

    @can_mass_edit_groups.size > 0 ? (user.in_any_group?(@can_mass_edit_groups)) : true
  end

  # returns true if the given user should be allowed to view this field
  def can_view? user
    in_groups = false
    everyone_can_view = false

    # If the field validator rule indicates everyone can view, then that will override any other checks, other than 
    # the can_view_lambda (essentially, it just overrides the groups checks)
    if @everyone_can_view
      everyone_can_view = @everyone_can_view
    else
      if @can_edit_groups.size > 0
        in_groups = user.in_any_group? @can_edit_groups
      end

      if !in_groups && @can_view_groups.size > 0
        in_groups = user.in_any_group? @can_view_groups
      end
    end

    can_view = false
    if everyone_can_view || in_groups || (@can_edit_groups.size == 0 && @can_view_groups.size == 0)
      # By default, there's no can_view_lambda so we assume the default state of the field
      # is viewable by all.
      if @can_view_lambda.nil?
        can_view = true
      else
        can_view = @can_view_lambda.call user
      end
    end

    can_view
  end

  def can_edit? user
    return false if self.read_only?
    # If there's any edit groups associated w/ the field, then the user MUST be in one of them to be able
    # to edit...there's no other means to be able to edit this field.

    # If there are no edit groups, then they either have to be in a view group or no groups
    # must exist for the field.  At which point, use the can_edit lambda if it exists, fall back to the
    # can_view lambda if it exists.  If can_edit / can_view lambdas don't exist, then we assume the field is
    # editable by all.
    return false if read_only?

    do_edit_lambda = false
    if @can_edit_groups.size > 0
      do_edit_lambda = user.in_any_group? @can_edit_groups
    else
      if @can_view_groups.size > 0
        do_edit_lambda = user.in_any_group? @can_view_groups
      else
        do_edit_lambda = true
      end
    end

    can_edit = false
    if do_edit_lambda
      if @can_edit_lambda.nil?
        if @can_view_lambda.nil?
          can_edit = true
        else
          can_edit = @can_view_lambda.call user
        end
      else
        can_edit = @can_edit_lambda.call user
      end
    end
    can_edit
  end

  # returns the default currency code for the value as a lowercase symbol (like :usd) or nil
  def currency
    @currency
  end

  def numeric?
    [:integer, :decimal].include? data_type 
  end

  def date?
    data_type == :date || data_type == :datetime
  end

  #should the entity snapshot system ignore this field when recording an item's history state
  def history_ignore?
    @history_ignore
  end

  #get the array of entity types for which this field should be displayed
  def entity_type_ids
    EntityTypeField.cached_entity_type_ids self
  end

  #does this field represent the "Entity Type" field for the module.  This is used by the application helper to
  #make sure that this field is always displayed (even if it is not on the entity type field list)
  def entity_type_field?
    @entity_type_field
  end

  def tool_tip
    tt = @custom_definition ? @custom_definition.tool_tip : ''
    tt.nil? ? '' : tt
  end

  #get the label that can be shown to the user.  If force_label is true or false, the CoreModule's prefix will or will not be appended.  If nil, it will use the default of the CoreModule's show_field_prefix
  def label(force_label=nil)
    prefix = ""
    if self.core_module
      do_prefix = force_label.nil? ? self.core_module.show_field_prefix : force_label
      prefix = do_prefix ? "#{self.core_module.label} - " : ""
    end

    "#{prefix}#{@label_override.nil? ? self.base_label : @label_override}"
  end

  #get the basic label content from the FieldLabel if available
  def base_label
    # Load the label once, and no longer even if it's nil - no point in relooking up nil over and over again
    return @base_label if defined?(@base_label)
    f = nil
    if @@field_label_cache.empty?
      f = FieldLabel.where(:model_field_uid=>@uid).first
    else
      f = @@field_label_cache[@uid]
    end
    if f.nil?
      #didn't find in database, check default cache or custom definition table
      if self.custom?
        @base_label = self.custom_definition.label
      else
        @base_label = FieldLabel.default_value @uid
      end
    else
      @base_label = f.label
    end
    @base_label
  end

  def qualified_field_name
    fn = nil
    if @qualified_field_name.nil?
      fn = "#{self.join_alias}.#{@field_name}"
    else
      fn = @qualified_field_name.respond_to?(:call) ? @qualified_field_name.call : @qualified_field_name
    end

    fn
  end

  def qualified_field_name_overridden?
    !@qualified_field_name.nil?
  end

  #table alias to use in where clause
  def join_alias
    if @join_alias.nil?
      @core_module.table_name
    else
      @join_alias
    end
  end
    #code to process when importing a field
  def process_import(obj, data, user, opts = {})
    # There's a couple of scenarios which are system operated where all access level checks should
    # be bypassed (snapshot restoration, being one).  This switch allows this.
    opts = {bypass_user_check: false}.merge opts
    v = nil
    if !opts[:bypass_read_only] && self.read_only?
      v = "Value ignored. #{self.label} is read only."
    else
      if opts[:bypass_user_check] || can_edit?(user)
        if @import_lambda.nil?
          d = [:date,:datetime].include?(self.data_type.to_sym) ? parse_date(data) : data
          if obj.is_a?(CustomValue)
            obj.value = d
          elsif self.custom?
            obj.find_and_set_custom_value(@custom_definition, d)
          else
            obj.send("#{@field_name}=".to_sym, d)
          end
          v = "#{self.label} set to #{d}"
        else
          if @import_lambda.arity == 2
            v = @import_lambda.call(obj, data)
          else
            v = @import_lambda.call(obj, data, user)
          end
        end
      else
        v = "You do not have permission to edit #{self.label}."
        def v.error?; true; end
      end

    end
    # Force all responses returned from the import lambda to have an error? method.
    if v && !v.respond_to?(:error?)
      def v.error?; false; end
    end
    v
  end

  #get the unformatted value that can be used for SearchCriterions
  def process_query_parameter obj
    @query_parameter_lambda.nil? ? process_export(obj, nil, true) : @query_parameter_lambda.call(obj)
  end

  #show the value for the given field or nil if the user does not have field level permission
  #if always_view is true, then the user permission check will be skipped
  def process_export obj, user, always_view = false
    if disabled?  || (!always_view && !can_view?(user))
      nil
    else
      value = nil
      if !obj.nil?
        if @export_lambda.nil?
          value = (self.custom? ? obj.custom_value(@custom_definition) : obj.send(@field_name))
        else
          value = @export_lambda.call(obj)
        end
      end

      value
    end
  end

  def custom?
    return !@custom_id.nil?
  end

  def public?
    @public
  end
  def public_searchable?
    @public_searchable
  end

  def determine_data_type
    if custom?
      custom_definition.data_type.downcase.to_sym
    else
      col = Kernel.const_get(@model).columns_hash[@field_name.to_s]
      # Interrogating the column class vs. using type returns the wrong value on integer types (fixnum instead of integer)
      # and boolean (object vs. boolean)
      return col.nil? ? nil : col.type #if col is nil, we probably haven't run the migration yet and are in the install process
    end
  end

  def blank?
    @uid == :____undef____ || @uid == :_blank
  end


  def self.admin_edit_lambda
    lambda {|u| u.admin?}
  end
  def self.blank_model_field
    if !defined?(@@blank_model_field)
      options = {
        import_lambda: lambda {|obj, data| "Field ignored"},
        export_lambda: lambda {|obj| nil},
        read_only: false,
        history_ignore: true,
        can_view_lambda: lambda {|u| false},
        query_parameter_lambda: lambda {|obj| nil},
        process_query_result_lambda: lambda {|obj| nil},
        data_type: :string,
        join_alias: "",
        qualified_field_name: "'#{ModelField.disabled_label}'",
        disabled: true,
        join_statement: "",
        label_override: ModelField.disabled_label
      }
      @@blank_model_field = ModelField.new 1000000, :____undef____, nil, "", options
    end

    @@blank_model_field
  end
  private_class_method :blank_model_field

  #called by the testing optimization in CustomDefinition.reset_cache
  def self.add_update_custom_field custom_definition
    core_module = CoreModule.find_by_class_name custom_definition.module_type
    return unless core_module

    model_hash = MODEL_FIELDS[core_module.class_name.to_sym]
    fld = custom_definition.model_field_uid.to_sym

    # If the custom definition is just being updated, we can just retrieve the existing
    # index and put it right back in place where it was
    if model_hash[fld]
      index = model_hash[fld].sort_rank
    else
      index = next_index_number(core_module)
    end

    create_and_insert_custom_field custom_definition, core_module, index
  end

  def self.create_and_insert_custom_field  custom_definition, core_module, index
    fld = custom_definition.model_field_uid.to_sym
    fields_to_add = []
    is_integer = custom_definition.data_type.to_sym==:integer
    if(is_integer && custom_definition.is_user?)
      fields_to_add.push(*build_user_fields(custom_definition, core_module, index))
    elsif(is_integer && custom_definition.is_address?)
      fields_to_add.push(*build_address_fields(custom_definition, core_module, index))
    else
      fields_to_add << ModelField.new(index,fld,core_module,fld,{custom_definition: custom_definition, label_override: "#{custom_definition.label}",
        qualified_field_name: "(SELECT #{custom_definition.data_column} FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} AND customizable_type = '#{custom_definition.module_type}')",
        definition: custom_definition.definition, default_label: "#{custom_definition.label}",
        cdef_uid: (custom_definition.cdef_uid.blank? ? nil : custom_definition.cdef_uid)
      })
    end
    add_model_fields core_module, fields_to_add
  end

  #should be after all class level methods are declared
  MODEL_FIELDS = Hash.new
  private_constant :MODEL_FIELDS
  # We don't want to retain disabled model fields in the main hash (since then we need
  # to update all the references to retrieving sets of model field to remove disabled ones
  # - which also gets expensive computationally).  But we do need to track which were disabled
  # because we don't want to do a reload in cases where a UID isn't in the model field hash
  # and is disabled...it's expensive to do so in queries.
  DISABLED_MODEL_FIELDS = Set.new
  private_constant :DISABLED_MODEL_FIELDS

  def self.field_validator_rule model_field_uid
    r = nil
    if @@field_validator_rules.empty?
      r = FieldValidatorRule.find_by_model_field_uid model_field_uid
    else
      r =  @@field_validator_rules[model_field_uid]
    end
    r
  end

  def self.add_fields(core_module,descriptor_array)
    descriptor_array.each do |m|
      options = m[4].nil? ? {} : m[4]
      options = {default_label: m[3]}.merge options

      mf = ModelField.new(m[0],m[1],core_module,m[2],options)
      add_model_fields(core_module, [mf])
    end
  end

  def self.add_model_fields(core_module, model_fields)
    module_type = module_type(core_module)
    MODEL_FIELDS[module_type] = Hash.new if MODEL_FIELDS[module_type].nil?

    model_fields.each do |mf|
      mf_uid = mf.uid.to_sym
      if mf.disabled?
        DISABLED_MODEL_FIELDS << mf_uid
      else
        DISABLED_MODEL_FIELDS.delete mf_uid
        MODEL_FIELDS[module_type][mf.uid.to_sym] = mf
      end
    end
  end

  def self.module_type core_module
    core_module.class_name.to_sym
  end
  private_class_method :module_type

  def self.remove_model_field(core_module, uid)
    fields = MODEL_FIELDS[module_type(core_module)]
    if fields
      fields.delete(uid.to_sym)
    end

    DISABLED_MODEL_FIELDS.delete uid.to_sym
  end

  def self.next_index_number(core_module)
    max = 0
    m_type = core_module.class_name.intern
    model_hash = MODEL_FIELDS[m_type]
    model_hash.values.each {|mf| max = mf.sort_rank + 1 if mf.sort_rank > max}
    max
  end

  #update the internal last_loaded flag and optionally retrigger all instances to invalidate their caches
  def self.update_last_loaded update_global_cache
    @@last_loaded = Time.now
    Rails.logger.info "Setting CACHE ModelField:last_loaded to \'#{@@last_loaded}\'" if update_global_cache
    CACHE.set "ModelField:last_loaded", @@last_loaded if update_global_cache
  end

  def self.last_loaded
    @@last_loaded ||= CACHE.get("ModelField:last_loaded")
    @@last_loaded ||= Time.now
    @@last_loaded
  end

  def self.reset_custom_fields(update_cache_time=false)
    CoreModule.all.each do |cm|
      h = MODEL_FIELDS[cm.class_name.to_sym]
      raise "No model fields configured for Core Module '#{cm.class_name}'." if h.nil?
      h.each do |k,v|
        if v.custom?
          h.delete k
          DISABLED_MODEL_FIELDS.delete v.uid
        end
      end
      ModelField.add_custom_fields_if_needed(cm, cm.class_name.constantize)
    end
    ModelField.create_and_insert_product_custom_fields(CoreModule::ORDER_LINE,@@custom_definition_cache)
    ModelField.create_and_insert_product_custom_fields(CoreModule::SHIPMENT_LINE,@@custom_definition_cache)
    ModelField.create_and_insert_variant_custom_fields(CoreModule::ORDER_LINE,@@custom_definition_cache)
    ModelField.create_and_insert_variant_custom_fields(CoreModule::SHIPMENT_LINE,@@custom_definition_cache)
    ModelField.update_last_loaded update_cache_time
  end

  def self.add_custom_fields_if_needed(core_module, base_class)
    ModelField.add_custom_fields(core_module, base_class) if CustomDefinition.cached_find_by_module_type(base_class).any?
  end

  #load the public field cache, then yield, clearing the cache after the yield returns
  def self.public_field_cache
    @@public_field_cache.clear
    begin
      @@public_field_cache[:warmed_cache] = 'x' #add a value so it's never empty since there's a good chance it will be
      PublicField.all.each {|f| @@public_field_cache[f.model_field_uid.to_sym] = f}
      return yield
    ensure
      @@public_field_cache.clear
    end
  end
  #load the field validator rules cache, then yield, clearing the cache after the yield returns
  def self.field_validator_rules_cache
    @@field_validator_rules.clear
    begin
      @@field_validator_rules[:warmed_cache] = 'x' #add a value so it's never empty since there's a good chance it will be
      FieldValidatorRule.all.each {|f| @@field_validator_rules[f.model_field_uid.to_sym] = f}
      return yield
    ensure
      @@field_validator_rules.clear
    end
  end
  #load the custom definition cache, then yield, clearing the cache after the yield returns
  def self.custom_definition_cache
    @@custom_definition_cache.clear
    begin
      @@custom_definition_cache[:warmed_cache] = 'x' #add a value so it's never empty
      CustomDefinition.all.each {|f| @@custom_definition_cache[f.model_field_uid.to_sym] = f}
      return yield
    ensure
      @@custom_definition_cache.clear
    end
  end

  def self.field_label_cache
    @@field_label_cache.clear
    begin
      FieldLabel.all.each {|f| @@field_label_cache[f.model_field_uid.to_sym] = f}
      return yield
    ensure
      @@field_label_cache.clear
    end
  end
  def self.warm_expiring_caches
    public_field_cache do
      field_validator_rules_cache do
        custom_definition_cache do
          field_label_cache do
            return yield
          end
        end
      end
    end
  end

  def self.reload(update_cache_time=false)
    warm_expiring_caches do
      FieldLabel.clear_defaults
      MODEL_FIELDS.clear
      DISABLED_MODEL_FIELDS.clear
      add_field_definitions
      reset_custom_fields update_cache_time
    end
  end

  reload #does the reload when the class is loaded the first time

  def self.find_by_uid(uid,dont_retry=false)
    uid = uid.model_field_uid if uid.is_a?(CustomDefinition)
    
    uid_sym = uid.to_sym
    return ModelField.new(10000,:_blank,nil,nil,{
      :label_override => "[blank]",
      :import_lambda => lambda {|o,d| "Field ignored"},
      :export_lambda => lambda {|o| },
      :data_type => :string,
      :qualified_field_name => "\"\""
    }) if uid_sym == :_blank

    return blank_model_field if DISABLED_MODEL_FIELDS.include?(uid_sym)

    reloaded = reload_if_stale

    return find_constant(uid) if constant_uid? uid
    
    MODEL_FIELDS.values.each do |h|
      mf = h[uid_sym]
      return mf unless mf.nil?
    end

    # There's little point to running a reload here if we just reloaded above
    unless reloaded || dont_retry || !allow_reload_double_check
      #reload and try again
      ModelField.reload true
      find_by_uid uid, true
    end

    return blank_model_field
  end

  def self.find_constant uid
    search_column_id = uid.to_s.split("_").last.to_i
    SearchColumn.find(search_column_id).model_field
  end

  # Should the find_by_uid method double check by reloading for missing fields
  # Defaults to true for non-test environment
  def self.allow_reload_double_check
    !Rails.env.test?
  end

  def self.viewable_model_fields user, fields
    f = []
    fields.each {|mf| f << mf if ModelField.find_by_uid(mf).can_view?(user)}
    f
  end

  # This method is largely just for testing purposes.  It does not reload
  # caches or anything.  You probably don't want to use it and should
  # opt for using find_by_uid instead.
  def self.model_field_loaded? uid
    MODEL_FIELDS.values.each do |h|
      u = uid.to_sym
      return true unless h[u].nil?
    end
    return false
  end

  #get array of model fields associated with the given region
  def self.find_by_region r
    ret = []
    uid_regex = /^\*r_#{r.id}_/
    reload_if_stale
    MODEL_FIELDS.values.each do |h|
      h.each do |k,v|
        ret << v if k.to_s.match uid_regex
      end
    end
    ret
  end

  def self.find_by_module_type(module_type)
    reload_if_stale

    if module_type.is_a?(CoreModule)
      module_type = module_type.class_name.to_sym
    elsif module_type.is_a?(String)
      module_type = module_type.to_sym
    end

    h = MODEL_FIELDS[module_type]
    # The values call below returns a new array each call
    # ensuring that modifications to the returned array
    # will not affect the internal model field list
    h.nil? ? [] : h.values.to_a
  end

  #get an array of model fields given core module
  def self.find_by_core_module cm
    find_by_module_type cm
  end

  def self.sort_by_label(mf_array, show_prefix = nil)
    # As any actual parameter to label actually means somehting (.ie nil is NOT the same as false)
    # break out the calls this way
    if show_prefix.nil?
      return mf_array.sort { |a,b| a.label <=> b.label }
    else
      return mf_array.sort { |a,b| a.label(show_prefix) <=> b.label(show_prefix) }
    end

  end

  def self.disabled_label
    "[Disabled]"
  end

  def self.reload_if_stale
    reloaded = false
    if !ModelField.disable_stale_checks #see documentation at disable_stale_checks accessor
      cache_time = CACHE.get "ModelField:last_loaded"
      if !cache_time.nil? && !cache_time.is_a?(Time)
        begin
          raise "cache_time was a #{cache_time.class} object!"
        rescue
          $!.log_me ["cache_time: #{cache_time.to_s}","cache_time class: #{cache_time.class.to_s}","@@last_loaded: #{@@last_loaded}"]
        ensure
          cache_time = nil
          reload
          reloaded = true
        end
      end
      if !cache_time.nil? && (@@last_loaded.nil? || @@last_loaded < cache_time)
        reload
        reloaded = true
      end
    end
    reloaded
  end

  def preprocess_search_value val
    if @search_value_preprocess_lambda
      @search_value_preprocess_lambda.call val
    else
      val
    end
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
