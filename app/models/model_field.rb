require 'open_chain/field_logic'
require 'open_chain/model_field_definition/full_model_field_definition'
require 'open_chain/model_field_generator/full_model_field_generator'

class ModelField
  extend OpenChain::ModelFieldGenerator::FullModelFieldGenerator
  extend OpenChain::ModelFieldDefinition::FullModelFieldDefinition

  # When web mode is true, the class assumes that there is a before filter calling ModelField.reload_if_stale at the beginning of every request.
  # This means the class won't call memchached on every call to ModelField.find_by_uid to see if the ModelFieldSetups are stale
  # This should not be used outside of the web environment where jobs will be long running
  cattr_accessor :web_mode

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
              :public, :public_searchable, :definition, :disabled, :field_validator_rule, :user_accessible

  def initialize(rank, uid, core_module, field_name, options={})
    o = {entity_type_field: false, history_ignore: false, read_only: false, user_accessible: true}.merge(options)
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
    @custom_id = o[:custom_id]
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
    self.custom_definition if @custom_id #load from cache if available
    @process_query_result_lambda = o[:process_query_result_lambda]
    @field_validator_rule = self.class.field_validator_rule uid
    @field_validator_rule = o[:field_validator_rule] ? o[:field_validator_rule] : @field_validator_rule
    @read_only = o[:read_only] || @field_validator_rule.try(:read_only?)

    # The respond_to here is pretty much solely there for the migration case when disabled? didn't
    # exist and the migration is creating it - unfortunately this is necesitated because
    # we have some initializers that reference model fields.
    @disabled = o[:disabled] || (@field_validator_rule.respond_to?(:disabled?) && @field_validator_rule.disabled?)
    @can_view_groups = SortedSet.new(@field_validator_rule.respond_to?(:view_groups) ? @field_validator_rule.view_groups : [])
    @can_edit_groups = SortedSet.new(@field_validator_rule.respond_to?(:edit_groups) ? @field_validator_rule.edit_groups : [])
    if !o[:default_label].blank?
      FieldLabel.set_default_value @uid, o[:default_label]
    end
    @user_accessible = o[:user_accessible]
    @user_field = o[:user_field]
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
    @custom_definition = @@custom_definition_cache[@uid] unless @custom_definition
    @custom_definition = CustomDefinition.find_by_id @custom_id unless @custom_definition
    @custom_definition
  end

  # if true, then the field can't be updated with `process_import`
  def read_only?
    @read_only
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

  # returns true if the given user should be allowed to view this field
  def can_view? user
    in_groups = false
    if @can_edit_groups.size > 0
      in_groups = user.in_any_group? @can_edit_groups
    end

    if !in_groups && @can_view_groups.size > 0
      in_groups = user.in_any_group? @can_view_groups
    end

    can_view = false
    if in_groups || (@can_edit_groups.size == 0 && @can_view_groups.size == 0)
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
    # If there's any edit groups associated w/ the field, then the user MUST be in one of them to be able
    # to edit...there's no other means to be able to edit this field.

    # If there are no edit groups, then they either have to be in a view group or no groups
    # must exist for the field.  At which point, use the can_edit lambda if it exists, fall back to the
    # can_view lambda if it exists.  If can_edit / can_view lambdas don't exist, then we assume the field is
    # editable by all.
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
    do_prefix = force_label.nil? && self.core_module ? self.core_module.show_field_prefix : force_label
    r = do_prefix ? "#{self.core_module.label} - " : ""
    return "#{r}#{@label_override}" unless @label_override.nil?
    "#{r}#{self.base_label}"
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
    @qualified_field_name.nil? ? "#{self.join_alias}.#{@field_name}" : @qualified_field_name
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
    if self.read_only?
      v = "Value ignored. #{self.label} is read only."
    else
      if opts[:bypass_user_check] || can_edit?(user)
        if @import_lambda.nil?
          d = [:date,:datetime].include?(self.data_type.to_sym) ? parse_date(data) : data
          if obj.is_a?(CustomValue)
            obj.value = d
          elsif self.custom?
            obj.get_custom_value(@custom_definition).value = d
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
          value = (self.custom? ? obj.get_custom_value(@custom_definition).value(@custom_definition) : obj.send(@field_name))
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
    module_type = core_module.class_name.to_sym
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

  def self.next_index_number(core_module)
    max = 0
    m_type = core_module.class_name.intern
    model_hash = MODEL_FIELDS[m_type]
    model_hash.values.each {|mf| max = mf.sort_rank + 1 if mf.sort_rank > max}
    max
  end

  def self.add_custom_fields(core_module,base_class)
    model_hash = MODEL_FIELDS[core_module.class_name.to_sym]
    base_class.new.custom_definitions.each_with_index do |d,index|
      create_and_insert_custom_field(d, core_module, next_index_number(core_module), model_hash)
    end
  end
  def self.create_and_insert_custom_field  custom_definition, core_module, index, model_hash
    fld = custom_definition.model_field_uid.to_sym
    fields_to_add = []
    if(custom_definition.data_type.to_sym==:integer && custom_definition.is_user?)
      uid_prefix = "*uf_#{custom_definition.id}_"
      fields_to_add << ModelField.new(index, "#{uid_prefix}username", core_module, "#{uid_prefix}username", {
        custom_id: custom_definition.id,
        label_override: "#{custom_definition.label} (Username)",
        qualified_field_name: "(SELECT IFNULL(users.username,\"\") FROM users WHERE users.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} AND customizable_type = '#{custom_definition.module_type}'))",
        definition: custom_definition.definition,
        import_lambda: lambda {|obj,data|
          user_id = nil
          u = User.find_by_username data
          user_id = u.id if u
          obj.get_custom_value(custom_definition).value = user_id
          return "#{custom_definition.label} set to #{u.nil? ? 'BLANK' : u.username}"
        },
        export_lambda: lambda {|obj|
          r = ""
          cv = obj.get_custom_value(custom_definition)
          user_id = cv.value
          if user_id
            u = User.find_by_id user_id
            r = u.username if u
          end
          return r
        },
        data_type: :string,
        field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
        user_field: true
      })
      fields_to_add << ModelField.new(index, "#{uid_prefix}fullname", core_module, "#{uid_prefix}fullname", {
        custom_id: custom_definition.id,
        label_override: "#{custom_definition.label} (Name)",
        qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(first_name, ''), IFNULL(last_name, '')) FROM users WHERE users.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} AND customizable_type = '#{custom_definition.module_type}'))",
        definition: custom_definition.definition,
        import_lambda: lambda {|obj,data|
          return "#{custom_definition.label} cannot be imported by full name, try the username field."
        },
        export_lambda: lambda {|obj|
          r = ""
          cv = obj.get_custom_value(custom_definition)
          user_id = cv.value
          if user_id
            u = User.find_by_id user_id
            r = u.full_name if u
          end
          return r
        },
        data_type: :string,
        field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
        read_only: true,
        user_field: true
      })
      fields_to_add << ModelField.new(index,fld,core_module,fld,{:custom_id=>custom_definition.id,:label_override=>"#{custom_definition.label}",
        :qualified_field_name=>"(SELECT IFNULL(#{custom_definition.data_column},\"\") FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} AND customizable_type = '#{custom_definition.module_type}')",
        :definition => custom_definition.definition, :default_label => "#{custom_definition.label}",
        :read_only => true
      })
    else
      fields_to_add << ModelField.new(index,fld,core_module,fld,{:custom_id=>custom_definition.id,:label_override=>"#{custom_definition.label}",
        :qualified_field_name=>"(SELECT IFNULL(#{custom_definition.data_column},\"\") FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} AND customizable_type = '#{custom_definition.module_type}')",
        :definition => custom_definition.definition, :default_label => "#{custom_definition.label}"
      })
    end
    add_model_fields core_module, fields_to_add
  end
  private_class_method :create_and_insert_custom_field

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

    create_and_insert_custom_field custom_definition, core_module, index, model_hash
  end

  # Add all Product Custom Definitions to given module
  def self.create_and_insert_product_custom_fields core_module
    start_index = next_index_number core_module
    prod_defs = []
    if @@custom_definition_cache.empty?
      prod_defs = CustomDefinition.where(module_type:'Product').to_a
    else
      prod_defs = @@custom_definition_cache.values.collect {|cd| cd.is_a?(CustomDefinition) && cd.module_type=='Product' ? cd : nil}.compact
    end
    prod_defs.each_with_index {|d,i| create_and_insert_product_custom_field d, core_module, start_index+i}
  end

  # Make a ModelField based on the given module that links through
  # to a product custom definition.
  def self.create_and_insert_product_custom_field custom_definition, core_module, index
    uid = "#{custom_definition.model_field_uid}_#{core_module.table_name}".to_sym
    mf = ModelField.new(index,uid,core_module,uid,{
      custom_id: custom_definition.id,
      label_override: custom_definition.label.to_s,
      qualified_field_name: "(SELECT IFNULL(#{custom_definition.data_column},\"\") FROM products INNER JOIN custom_values ON custom_values.customizable_id = products.id AND custom_values.customizable_type = 'Product' and custom_values.custom_definition_id = #{custom_definition.id} WHERE products.id = #{core_module.table_name}.product_id)",
      definition: custom_definition.definition,
      default_label: custom_definition.label.to_s,
      read_only: true,
      export_lambda: lambda { |o|
        p = o.product
        return nil if p.nil?
        p.get_custom_value(custom_definition).value
      }
    })
    add_model_fields core_module, [mf]
    mf
  end

  #update the internal last_loaded flag and optionally retrigger all instances to invalidate their caches
  def self.update_last_loaded update_global_cache
    @@last_loaded = Time.now
    Rails.logger.info "Setting CACHE ModelField:last_loaded to \'#{@@last_loaded}\'" if update_global_cache
    CACHE.set "ModelField:last_loaded", @@last_loaded if update_global_cache
  end

  def self.reset_custom_fields(update_cache_time=false)
    CoreModule::CORE_MODULES.each do |cm|
      h = MODEL_FIELDS[cm.class_name.to_sym]
      h.each do |k,v|
        if !v.custom_id.nil?
          h.delete k
          DISABLED_MODEL_FIELDS.delete v.uid
        end
      end
    end
    ModelField.add_custom_fields(CoreModule::ORDER,Order)
    ModelField.add_custom_fields(CoreModule::ORDER_LINE,OrderLine)
    ModelField.create_and_insert_product_custom_fields(CoreModule::ORDER_LINE)
    ModelField.add_custom_fields(CoreModule::PRODUCT,Product)
    ModelField.add_custom_fields(CoreModule::CLASSIFICATION,Classification)
    ModelField.add_custom_fields(CoreModule::TARIFF,TariffRecord)
    ModelField.add_custom_fields(CoreModule::CONTAINER,Container)
    ModelField.add_custom_fields(CoreModule::SHIPMENT,Shipment)
    ModelField.add_custom_fields(CoreModule::SHIPMENT_LINE,ShipmentLine)
    ModelField.add_custom_fields(CoreModule::SALE,SalesOrder)
    ModelField.add_custom_fields(CoreModule::SALE_LINE,SalesOrderLine)
    ModelField.add_custom_fields(CoreModule::DELIVERY,Delivery)
    ModelField.add_custom_fields(CoreModule::ENTRY,Entry)
    ModelField.add_custom_fields(CoreModule::BROKER_INVOICE,BrokerInvoice)
    ModelField.add_custom_fields(CoreModule::BROKER_INVOICE_LINE,BrokerInvoiceLine)
    ModelField.add_custom_fields(CoreModule::SECURITY_FILING,SecurityFiling)
    ModelField.add_custom_fields(CoreModule::COMPANY,Company)
    ModelField.add_custom_fields(CoreModule::PLANT,Plant)
    ModelField.add_custom_fields(CoreModule::PLANT_PRODUCT_GROUP_ASSIGNMENT,PlantProductGroupAssignment)
    ModelField.update_last_loaded update_cache_time
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

    MODEL_FIELDS.values.each do |h|
      mf = h[uid_sym]
      return mf unless mf.nil?
    end

    # There's little point to running a reload here if we just reloaded above
    unless reloaded || dont_retry
      #reload and try again
      ModelField.reload true
      find_by_uid uid, true
    end

    return blank_model_field
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

  def self.find_by_module_type_and_uid(type_symbol,uid_symbol)
    find_by_module_type(type_symbol).each { |mf|
      return mf if mf.uid == uid_symbol
    }
    return nil
  end

  def self.find_by_module_type_and_custom_id(type_symbol,id)
    find_by_module_type(type_symbol).each {|mf|
      return mf if mf.custom_id==id
      }
    return nil
  end

  def self.sort_by_label(mf_array)
    return mf_array.sort { |a,b| a.label <=> b.label }
  end

  def self.disabled_label
    "[Disabled]"
  end

  def self.reload_if_stale
    reloaded = false
    if !ModelField.web_mode #see documentation at web_mode accessor
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
