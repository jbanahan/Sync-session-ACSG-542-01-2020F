class CoreModule
  attr_reader :class_name, :label, :table_name,
      :new_object_lambda,
      :children, #array of child CoreModules used for :has_many (not for :belongs_to)
      :child_lambdas, #hash of lambdas to access child CoreModule data
      :child_joins, #hash of join statements to link up child CoreModule to parent
      :statusable, #works with status rules
      :worksheetable, #works with worksheet uploads
      :file_formatable, #can be used for file formats
      :default_search_columns, #array of columns to be included when a default search is created
      :show_field_prefix, #should the default option for this module's field's labels be to show the module name as a prefix (true =  "Classification - Country Name", false="Country Name")
      :changed_at_parents_lambda, #lambda returning array of objects that should have their changed_at value updated on this module's object's after_save triggers,
      :object_from_piece_set_lambda, #lambda returning the appropriate object for this module based on the given PieceSet (or nil)
      :entity_json_lambda, #lambda return hash suitable for conversion into json containing all model fields
      :business_logic_validations, #lambda accepts object, sets internal errors for any business rules validataions, returns true for pass and false for fail
      :enabled_lambda, #is the module enabled in master setup
      :key_model_field_uids, #the uids represented by this array of model_field_uids can be used to find a unique record in the database
      :view_path_proc, # Proc (so you can change execution context via instance_exec and thus use path helpers) used to determine view path for the module (may return null if no view path exists)
      :edit_path_proc, # Proc (so you can change execution context via instance_exec and thus use path helpers) used to determine edit path for the module (may return null if no edit path exists)
      :quicksearch_lambda, # Scope for quick searching
      :quicksearch_fields # List of field / field definitions for quicksearching
  attr_accessor :default_module_chain #default module chain for searches, needs to be read/write because all CoreModules need to be initialized before setting

  def initialize(class_name,label,opts={})
    o = {:worksheetable => false, :statusable=>false, :file_format=>false,
        :new_object => lambda {Kernel.const_get(class_name).new},
        :children => [], :make_default_search => lambda {|user|
          ss = SearchSetup.create(:name=>"Default",:user => user,:module_type=>class_name,:simple=>false)
          model_fields.keys.each_with_index do |uid,i|
            ss.search_columns.create(:rank=>i,:model_field_uid=>uid) if i < 3
          end
          ss
        },
        :business_logic_validations => lambda {|base_object| true},
        :bulk_actions_lambda => lambda {|current_user| return Hash.new},
        :changed_at_parents_lambda => lambda {|base_object| []},
        :show_field_prefix => false,
        :entity_json_lambda => lambda { |entity,module_chain|
          master_hash = {'entity'=>{'core_module'=>self.class_name,'record_id'=>entity.id,'model_fields'=>{}}}
          mf_hash = master_hash['entity']['model_fields']
          self.model_fields.values.each do |mf|
            unless mf.history_ignore?
              v = mf.process_export entity, nil, true
              mf_hash[mf.uid] = v unless v.nil?
            end
          end
          child_mc = module_chain.child self
          unless child_mc.nil?
            child_objects = self.child_objects(child_mc,entity)
            unless child_objects.blank?
              eca = []
              master_hash['entity']['children'] = eca
              child_objects.each do |c|
                eca << child_mc.entity_json_lambda.call(c,module_chain)
              end
            end
          end
          master_hash
        },
        :object_from_piece_set_lambda => lambda {|ps| nil},
        :enabled_lambda => lambda { true },
        :key_model_field_uids => []
      }.
      merge(opts)
    @class_name = class_name
    @label = label
    @table_name = class_name.underscore.pluralize
    @statusable = o[:statusable]
    @worksheetable = o[:worksheetable]
    @file_formatable = o[:file_formatable]
    @new_object_lambda = o[:new_object]
    @children = o[:children]
    @child_lambdas = o[:child_lambdas]
    @child_joins = o[:child_joins]
    @default_search_columns = o[:default_search_columns]
    @bulk_actions_lambda = o[:bulk_actions_lambda]
    @changed_at_parents_lambda = o[:changed_at_parents_lambda]
    @show_field_prefix = o[:show_field_prefix]
    @entity_json_lambda = o[:entity_json_lambda]
    @unique_id_field_name = o[:unique_id_field_name]
    @object_from_piece_set_lambda = o[:object_from_piece_set_lambda]
    @enabled_lambda = o[:enabled_lambda]
    @business_logic_validations = o[:business_logic_validations]
    @key_model_field_uids = o[:key_model_field_uids]
    if o[:edit_path_proc].nil?
      # The result handles cases where the path doesn't exist.  This code was largely hoisted from search_query_controller_helper 
      # which did basically the same thing...so we don't care if we get objects that don't have edit paths.
      @edit_path_proc = Proc.new {|obj| edit_polymorphic_path(obj) rescue nil }
    else
      @edit_path_proc = o[:edit_path_proc]
    end

    if o[:view_path_proc].nil?
      # See above for comment about edit paths
      @view_path_proc = Proc.new {|obj| polymorphic_path(obj) rescue nil }
    else
      @view_path_proc = o[:view_path_proc]
    end

    if o[:quicksearch_lambda]
      @quicksearch_lambda = o[:quicksearch_lambda]
    else
      @quicksearch_lambda = lambda {|user, scope| klass.search_secure(user, scope)}
    end

    @quicksearch_fields = o[:quicksearch_fields]
    @quicksearch_sort_by_mf = o[:quicksearch_sort_by_mf]

    @available_addresses_lambda = o[:available_addresses_lambda]

    @logical_key_lambda = o[:logical_key_lambda]
  
  end

  def quicksearch_sort_by  #returns qualified field name. Getter avoids circular dependency during init
    unless @quicksearch_sort_by_qfn
      qsbmf = ModelField.find_by_uid(@quicksearch_sort_by_mf ? @quicksearch_sort_by_mf : :nil)
      @quicksearch_sort_by_qfn = qsbmf.blank? ? "#{@table_name}.created_at" : qsbmf.qualified_field_name
    end
    @quicksearch_sort_by_qfn
  end

  #lambda accepts object, sets internal errors for any business rules validataions, returns true for pass and false for fail
  def validate_business_logic base_object
    @business_logic_validations.call(base_object)
  end
  #returns the appropriate object for the core module based on the piece set given
  def object_from_piece_set piece_set
    @object_from_piece_set_lambda.call piece_set
  end
  #returns the model field that you can show to the user to uniquely identify the record
  def unique_id_field
    ModelField.find_by_uid @unique_id_field_name
  end

  # returns a unique key for this instance based on the object given
  def logical_key base_object
    return @logical_key_lambda.call(base_object) if @logical_key_lambda
    self.unique_id_field.process_export(base_object,nil,true)
  end

  #can the user view items for this module
  def view? user
    user.view_module? self
  end

  #returns a json representation of the entity and all of it's children
  def entity_json base_object
    j = @entity_json_lambda.call(base_object,default_module_chain)
    ActiveSupport::JSON.encode j
  end

  #find's the given objects parents that should have their changed_at values updated, updates them, and saves them.
  #This method will not re-update or save a changed_at value that is less than 1 minute old to save on constant DB writes
  def touch_parents_changed_at base_object
    @changed_at_parents_lambda.call(base_object).each do |p|
      ca = p.changed_at
      if ca.nil? || ca < 1.minute.ago
        p.changed_at = Time.now
        p.save
      end
    end
  end

  def default_module_chain
    return @default_module_chain unless @default_module_chain.nil?
    @default_module_chain = ModuleChain.new
    @default_module_chain.add self
    @default_module_chain
  end

  def bulk_actions user
    @bulk_actions_lambda.call user
  end

  def make_default_search(user)
    dsc = ModelField.viewable_model_fields user, @default_search_columns
    SearchSetup.create_with_columns(self, dsc, user)
  end
  #can have status set on the module
  def statusable?
    @statusable
  end
  #can have worksheets uploaded
  def worksheetable?
    @worksheetable
  end
  #can be used as the base for an import/export file format
  def file_formatable?
    @file_formatable
  end

  def new_object
    @new_object_lambda.call
  end

  def find id
    klass.find id
  end

  # return the class represented by the core module
  def klass
    Kernel.const_get(class_name)
  end

  # Hash of model_fields keyed by UID, this method is
  # returns all user accessible methods the (optional) user is capable of viewing
  def model_fields user=nil
    r = ModelField.find_by_core_module self
    h = {}
    r.each do |mf|
      if mf.user_accessible? && (user.nil? || mf.can_view?(user))
        add = block_given? ? yield(mf) : true
        h[mf.uid.to_sym] = mf if add
      end
    end
    h
  end

  #hash of model_fields for core_module and any core_modules referenced as children
  #and their children recursively
  def model_fields_including_children user=nil
    r = block_given? ? model_fields(user, &Proc.new) : model_fields(user)
    @children.each do |c|
      r = r.merge(block_given? ? c.model_fields_including_children(user, &Proc.new) : c.model_fields_including_children(user))
    end
    r
  end

  def every_model_field
    r = ModelField.find_by_core_module self
    h = {}
    r.each do |mf|
      add = block_given? ? yield(mf) : true
      h[mf.uid.to_sym] = mf if add
    end
    h
  end

  def every_model_field_including_children
    r = block_given? ? every_model_field(user, &Proc.new) : every_model_field(user)
    @children.each do |c|
      r = r.merge(block_given? ? c.every_model_field_including_children(&Proc.new) : c.every_model_field_including_children())
    end
    r
  end

  def child_objects(child_core_module,base_object)
    # If you call this on a leaf level core module (.ie tariff record) then the child lambda
    # is likely nil, so just return an empty array
    lmda = @child_lambdas ? @child_lambdas[child_core_module] : nil
    lmda ? lmda.call(base_object) : []
  end

  #how many steps away is the given module from this one in the parent child tree
  def module_level(core_module)
    CoreModule.recursive_module_level(0,self,core_module)
  end

  def child_association_name(child_core_module)
    child_class = child_core_module.klass
    name = child_class.to_s.underscore.pluralize

    if klass.reflect_on_association(name.to_sym).nil?
      name = nil
      klass.reflections.each_pair do |assoc_name, reflection|
        if reflection.macro == :has_many && reflection.active_record == child_class
          name = assoc_name.to_s
          break
        end
      end
    end

    # This should never actually happen, something's wrong if it does, so raise an argument error
    raise ArgumentError, "Failed to find association for #{child_class} in #{klass}." if name.nil?

    name
  end

  #get all addresses associated with object
  def available_addresses obj
    @available_addresses_lambda ? @available_addresses_lambda.call(obj) : []
  end

  include CoreModuleDefinitions

  def self.all
    self.constants.map{|c| self.const_get(c)}.select{|c| c.is_a? CoreModule} || []
  end

  CORE_MODULES = CoreModule.all

  def self.add_virtual_identifier
    # Add in the virtual_identifier field that is needed for update_model_field_attribute support
    # This field is explained in the UpdateModelFieldsSupport module.
    # It's only here becuase I couldn't figure out a way to meta-program it into that module and make sure
    # the field was added to all child core modules as well.

    # This appears to have to be done outside the CoreModule constructors becuase of the circular reference
    # to CoreModule inside the core module classes (.ie Product, Entry, etc)
    self.all.each {|cm| cm.klass.class_eval{attr_accessor :virtual_identifier unless self.respond_to?(:virtual_identifier=)}}
  end
  private_class_method :add_virtual_identifier

  add_virtual_identifier

  def self.set_default_module_chain(core_module, core_module_array)
    mc = ModuleChain.new
    mc.add_array core_module_array
    core_module.default_module_chain = mc
  end

  set_default_module_chain ORDER, [ORDER,ORDER_LINE]
  set_default_module_chain SHIPMENT, [SHIPMENT,SHIPMENT_LINE,BOOKING_LINE]
  set_default_module_chain PRODUCT, [PRODUCT, CLASSIFICATION, TARIFF]
  set_default_module_chain SALE, [SALE,SALE_LINE]
  set_default_module_chain DELIVERY, [DELIVERY,DELIVERY_LINE]
  set_default_module_chain ENTRY, [ENTRY,COMMERCIAL_INVOICE,COMMERCIAL_INVOICE_LINE,COMMERCIAL_INVOICE_TARIFF]
  set_default_module_chain BROKER_INVOICE, [BROKER_INVOICE,BROKER_INVOICE_LINE]
  set_default_module_chain SECURITY_FILING, [SECURITY_FILING,SECURITY_FILING_LINE]
  set_default_module_chain COMPANY, [COMPANY, PLANT, PLANT_PRODUCT_GROUP_ASSIGNMENT]

  def self.find_by_class_name(c,case_insensitive=false)
    self.all.each do|m|
      if case_insensitive
        return m if m.class_name.downcase == c.downcase
      else
        return m if m.class_name == c
      end
    end
    return nil
  end

  def self.find_by_object(obj)
    find_by_class_name obj.class.to_s
  end

  def self.find_file_formatable
    test_to_array {|c| c.file_formatable?}
  end

  def self.find_statusable
    test_to_array {|c| c.statusable?}
  end

  #make array of arrays for use in select boxes
  def self.to_a_label_class
    to_proc = test_to_array {|c| block_given? ? (yield c) : true}
    r = []
    to_proc.each {|c| r << [c.label,c.class_name]}
    r
  end

  #make hash of arrays to work with FormOptionsHelper.grouped_options_for_select
  def self.grouped_options user, opts = {}
    inner_opts = {:core_modules => self.all, :filter=>lambda {|f| true}}.merge(opts)
    core_modules = inner_opts[:core_modules].select {|cm| user.view_module? cm}.sort {|x,y| x.label <=> y.label}

    r = {}
    core_modules.each do |cm|
      flds = cm.every_model_field {|mf| mf.can_view?(user) && inner_opts[:filter].call(mf)}
      r[cm.label] = flds.map {|k, v| [v.label,k]}.sort {|x, y| x[0] <=> y[0]}
    end
    r
  end

  def enabled?
    @enabled_lambda.call
  end

  def self.walk_object_heirarchy object, core_module = nil
    core_module = find_by_object(object) if core_module.nil?
    yield core_module, object

    child_core_module = core_module.children.first
    children = core_module.child_objects(child_core_module, object)
    children.each do |c|
      walk_object_heirarchy c, child_core_module, &Proc.new
    end

    nil
  end

  private
  def self.test_to_array
    r = []
    self.all.each {|c| r << c if yield c}
    r
  end

  def self.recursive_module_level(start_level,current_module,target_module)
    if current_module == target_module
      return start_level + 0
    elsif current_module.children.include? target_module
      return start_level + 1
    else
      r_val = nil
      current_module.children.each do |cm|
        r_val = recursive_module_level(start_level+1,cm,target_module) if r_val.nil?
      end
      return r_val
    end
  end
end
