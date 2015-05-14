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
    reflections = klass.reflections

    if reflections[name.to_sym].nil?
      name = nil
      reflections.each_pair do |assoc_name, reflection|
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

  SECURITY_FILING_LINE = new("SecurityFilingLine","Security Line", {
    :show_field_prefix=>true,
    :unique_id_field_name=>:sfln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.security_filing_line},
    :enabled_lambda => lambda {MasterSetup.get.security_filing_enabled?},
    :key_model_field_uids=>[:sfln_line_number]
  })
  SECURITY_FILING = new("SecurityFiling","Security Filing",{
    :unique_id_field_name=>:sf_transaction_number,
    :object_from_piece_set_lambda => lambda {|ps|
      s_line = ps.security_filing_line
      s_line.nil? ? nil : s_line.security_filing
    },
    :children => [SECURITY_FILING_LINE],
    :child_lambdas => {SECURITY_FILING_LINE => lambda {|parent| parent.security_filing_lines}},
    :child_joins => {SECURITY_FILING_LINE => "LEFT OUTER JOIN security_filing_lines ON security_filings.id = security_filing_lines.security_filing_id"},
    :default_search_columns => [:sf_transaction_number],
    :enabled_lambda => lambda {MasterSetup.get.security_filing_enabled?},
    :key_model_field_uids => [:sf_transaction_number],
    :quicksearch_fields => [:sf_transaction_number,:sf_entry_numbers,:sf_entry_reference_numbers,:sf_po_numbers,:sf_master_bill_of_lading,:sf_container_numbers,:sf_house_bills_of_lading, :sf_host_system_file_number]
  })
  ORDER_LINE = new("OrderLine","Order Line",{
    :show_field_prefix=>true,
    :unique_id_field_name=>:ordln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.order_line},
    :enabled_lambda => lambda { MasterSetup.get.order_enabled? },
    :key_model_field_uids => [:ordln_line_number]
  })
  ORDER = new("Order","Order",
    {:file_formatable=>true,
      :children => [ORDER_LINE],
      :child_lambdas => {ORDER_LINE => lambda {|parent| parent.order_lines}},
      :child_joins => {ORDER_LINE => "LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id"},
      :default_search_columns => [:ord_ord_num,:ord_ord_date,:ord_ven_name,:ordln_puid,:ordln_ordered_qty],
      :unique_id_field_name => :ord_ord_num,
      :object_from_piece_set_lambda => lambda {|ps|
        o_line = ps.order_line
        o_line.nil? ? nil : o_line.order
      },
      :enabled_lambda => lambda { MasterSetup.get.order_enabled? },
      :key_model_field_uids => [:ord_ord_num],
      :quicksearch_fields => [:ord_ord_num, :ord_cust_ord_no]
    })
  CONTAINER = new("Container", "Container", {
    show_field_prefix: false,
    unique_id_field_name: :con_num,
    object_from_piece_set_lambda: lambda {|ps| ps.shipment_line.nil? ? nil : sp.shipment_line.container},
    enabled_lambda: lambda {MasterSetup.get.shipment_enabled?},
    key_model_field_uids: [:con_uid]
    })
  CARTON_SET = new("CartonSet","Carton Set",{
    show_field_prefix: false,
    unique_id_field_name: :cs_starting_carton,
    object_from_piece_set_lambda: lambda {|ps|
      return nil if ps.shipment_line.nil?
      ps.shipment_line.carton_set.nil? ? nil : ps.shipment_line.carton_set
      },
    enabled_lambda: lambda {MasterSetup.get.shipment_enabled?},
    key_model_field_uids: [:cs_starting_carton]
    })
  SHIPMENT_LINE = new("ShipmentLine", "Shipment Line",{
    :show_field_prefix=>true,
    :unique_id_field_name=>:shpln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.shipment_line},
    :enabled_lambda => lambda { MasterSetup.get.shipment_enabled? },
    :key_model_field_uids => [:shpln_line_number]
  })
  SHIPMENT = new("Shipment","Shipment",
    {:children=>[SHIPMENT_LINE],
    :child_lambdas => {SHIPMENT_LINE => lambda {|p| p.shipment_lines}},
    :child_joins => {SHIPMENT_LINE => "LEFT OUTER JOIN shipment_lines on shipments.id = shipment_lines.shipment_id"},
    :default_search_columns => [:shp_ref,:shp_mode,:shp_ven_name,:shp_car_name],
    :unique_id_field_name=>:shp_ref,
    :object_from_piece_set_lambda => lambda {|ps| ps.shipment_line.nil? ? nil : ps.shipment_line.shipment},
    :enabled_lambda => lambda { MasterSetup.get.shipment_enabled? },
    :key_model_field_uids => [:shp_ref],
    :quicksearch_fields => [:shp_ref,:shp_master_bill_of_lading,:shp_house_bill_of_lading,:shp_booking_number]
    })
  SALE_LINE = new("SalesOrderLine","Sale Line",{
    :show_field_prefix=>true,
    :unique_id_field_name=>:soln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.sales_order_line},
    :enabled_lambda => lambda { MasterSetup.get.sales_order_enabled? },
    :key_model_field_uids => [:soln_line_number]
    })
  SALE = new("SalesOrder","Sale",
    {:children => [SALE_LINE],
      :child_lambdas => {SALE_LINE => lambda {|parent| parent.sales_order_lines}},
      :child_joins => {SALE_LINE => "LEFT OUTER JOIN sales_order_lines ON sales_orders.id = sales_order_lines.sales_order_id"},
      :default_search_columns => [:sale_order_number,:sale_order_date,:sale_cust_name],
      :unique_id_field_name=>:sale_order_number,
      :object_from_piece_set_lambda => lambda {|ps| ps.sales_order_line.nil? ? nil : ps.sales_order_line.sales_order},
      :enabled_lambda => lambda { MasterSetup.get.sales_order_enabled? },
      :key_model_field_uids => [:sale_order_number],
      :quicksearch_fields => [:sale_order_number]
    })
  DELIVERY_LINE = new("DeliveryLine","Delivery Line",{
    :show_field_prefix=>true,
    :unique_id_field_name=>:delln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.delivery_line},
    :enabled_lambda => lambda { MasterSetup.get.delivery_enabled? },
    :key_model_field_uids => [:delln_line_number]
    })
  DELIVERY = new("Delivery","Delivery",
    {:children=>[DELIVERY_LINE],
    :child_lambdas => {DELIVERY_LINE => lambda {|p| p.delivery_lines}},
    :child_joins => {DELIVERY_LINE => "LEFT OUTER JOIN delivery_lines on deliveries.id = delivery_lines.delivery_id"},
    :default_search_columns => [:del_ref,:del_mode,:del_car_name,:del_cust_name],
    :unique_id_field_name=>:del_ref,
    :object_from_piece_set_lambda => lambda {|ps| ps.delivery_line.nil? ? nil : ps.delivery_line.delivery},
    :enabled_lambda => lambda { MasterSetup.get.delivery_enabled? },
    :key_model_field_uids => [:del_ref],
    :quicksearch_fields => [:del_ref]
    })
  TARIFF = new("TariffRecord","Tariff",{
    :changed_at_parents_lambda=>lambda {|tr|
      r = []
      c = tr.classification
      unless c.nil?
        p = c.product
        r << p unless p.nil?
      end
      r
    },
    :show_field_prefix=>true,
    :unique_id_field_name=>:hts_line_number,
    :enabled_lambda => lambda { MasterSetup.get.classification_enabled? },
    :key_model_field_uids => [:hts_line_number]
  })
  CLASSIFICATION = new("Classification","Classification",{
      :children => [TARIFF],
      :child_lambdas => {TARIFF => lambda {|p| p.tariff_records}},
      :child_joins => {TARIFF => "LEFT OUTER JOIN tariff_records ON classifications.id = tariff_records.classification_id"},
      :changed_at_parents_lambda=>lambda {|c| c.product.nil? ? [] : [c.product] },
      :show_field_prefix=>true,
      :unique_id_field_name=>:class_cntry_iso,
      :enabled_lambda => lambda { MasterSetup.get.classification_enabled? },
      :key_model_field_uids => [:class_cntry_name,:class_cntry_iso],
      :key_attribute_field_uid => :class_cntry_id
  })
  PRODUCT = new("Product","Product",{:statusable=>true,:file_formatable=>true,:worksheetable=>true,
      :children => [CLASSIFICATION],
      :child_lambdas => {CLASSIFICATION => lambda {|p| p.classifications}},
      :child_joins => {CLASSIFICATION => "LEFT OUTER JOIN classifications ON products.id = classifications.product_id"},
      :default_search_columns => [:prod_uid,:prod_name,:prod_first_hts,:prod_ven_name],
      :bulk_actions_lambda => lambda {|current_user|
        bulk_actions = {}
        bulk_actions["Edit"]='bulk_edit_products_path' if current_user.edit_products? || current_user.edit_classifications?
        bulk_actions["Classify"]={:path=>'/products/bulk_classify.json',:callback=>'BulkActions.submitBulkClassify',:ajax_callback=>'BulkActions.handleBulkClassify'} if current_user.edit_classifications?
        bulk_actions["Instant Classify"]='show_bulk_instant_classify_products_path' if current_user.edit_classifications? && !InstantClassification.scoped.empty?
        bulk_actions
      },
      :changed_at_parents_lambda=>lambda {|p| [p]},#only update self
      :business_logic_validations=>lambda {|p|
        c = p.errors[:base].size
        p.validate_tariff_numbers
        c==p.errors[:base].size
      },
      :unique_id_field_name=>:prod_uid,
      :key_model_field_uids => [:prod_uid],
      :quicksearch_fields => [:prod_uid,:prod_name]
  })
  BROKER_INVOICE_LINE = new("BrokerInvoiceLine","Broker Invoice Line",{
    :changed_at_parents_labmda => lambda {|p| p.broker_invoice.nil? ? [] : [p.broker_invoice]},
    :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
    :unique_id_field_name=>:bi_line_charge_code,
    :key_model_field_uids=>[:bi_line_charge_code]
  })
  BROKER_INVOICE = new("BrokerInvoice","Broker Invoice",{
    :default_search_columns => [:bi_brok_ref,:bi_suffix,:bi_invoice_date,:bi_invoice_total],
    :unique_id_field_name => :bi_suffix,
    :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
    :key_model_field_uids=>[:bi_brok_ref,:bi_suffix],
    :children => [BROKER_INVOICE_LINE],
    :child_lambdas => {BROKER_INVOICE_LINE => lambda {|i| i.broker_invoice_lines}},
    :child_joins => {BROKER_INVOICE_LINE => "LEFT OUTER JOIN broker_invoice_lines on broker_invoices.id = broker_invoice_lines.broker_invoice_id"},
    :quicksearch_fields => [:bi_invoice_number, {model_field_uid: :bi_brok_ref, joins: [:entry]}]
  })
  COMMERCIAL_INVOICE_TARIFF = new("CommercialInvoiceTariff","Invoice Tariff",{
    :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
    :show_field_prefix => true,
    :unique_id_field_name=>:cit_hts_code,
    :key_model_field_uids=>[:cit_hts_code]
  })
  COMMERCIAL_INVOICE_LINE = new("CommercialInvoiceLine","Invoice Line",{
    :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
    :show_field_prefix=>true,
    :unique_id_field_name=>:cil_line_number,
    :key_model_field_uids=>[:cil_line_number],
    :children => [COMMERCIAL_INVOICE_TARIFF],
    :child_lambdas => {COMMERCIAL_INVOICE_TARIFF=>lambda {|i| i.commercial_invoice_tariffs}},
    :child_joins => {COMMERCIAL_INVOICE_TARIFF=> "LEFT OUTER JOIN commercial_invoice_tariffs on commercial_invoice_lines.id = commercial_invoice_tariffs.commercial_invoice_line_id"}
  })
  COMMERCIAL_INVOICE = new("CommercialInvoice","Invoice",{
    :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
    :unique_id_field_name => :invoice_number,
    :show_field_prefix=>true,
    :key_model_field_uids=>[:invoice_number],
    :children => [COMMERCIAL_INVOICE_LINE],
    :child_lambdas => {COMMERCIAL_INVOICE_LINE=> lambda {|i| i.commercial_invoice_lines}},
    :child_joins => {COMMERCIAL_INVOICE_LINE => "LEFT OUTER JOIN commercial_invoice_lines on commercial_invoices.id = commercial_invoice_lines.commercial_invoice_id"}
  })
  ENTRY = new("Entry","Entry",{
    :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
    :default_search_columns => [:ent_brok_ref,:ent_entry_num,:ent_release_date],
    :unique_id_field_name=>:ent_brok_ref,
    :key_model_field_uids=>[:ent_brok_ref],
    :bulk_actions_lambda => lambda {|current_user|
      bulk_actions = {}
      bulk_actions["Update Images"] = "bulk_get_images_entries_path" if current_user.company.master? && current_user.view_entries?
      bulk_actions
    },
    :children => [COMMERCIAL_INVOICE],
    :child_lambdas => {COMMERCIAL_INVOICE => lambda {|ent| ent.commercial_invoices}},
    :child_joins => {COMMERCIAL_INVOICE => "LEFT OUTER JOIN commercial_invoices on entries.id = commercial_invoices.entry_id"},
    :quicksearch_fields => [:ent_brok_ref,:ent_entry_num,:ent_po_numbers,:ent_customer_references,:ent_mbols,:ent_container_nums,:ent_cargo_control_number,:ent_hbols,:ent_commercial_invoice_numbers]
  })
  OFFICIAL_TARIFF = new("OfficialTariff","HTS Regulation",:default_search_columns=>[:ot_hts_code,:ot_cntry_iso,:ot_full_desc,:ot_common_rate], :quicksearch_fields=> [:ot_hts_code,:ot_full_desc])
  PLANT_PRODUCT_GROUP_ASSIGNMENT = new('PlantProductGroupAssignment','Plant Product Group Assignment',default_search_columns:[:ppga_pg_name], show_field_prefix: true)
  PLANT = new("Plant","Plant", 
    default_search_columns: [:plant_name],
    unique_id_field_name: :plant_name,
    show_field_prefix: true,
    key_model_field_uids: [:plant_name],
    children: [PLANT_PRODUCT_GROUP_ASSIGNMENT],
    child_lambdas: {PLANT_PRODUCT_GROUP_ASSIGNMENT => lambda {|p| p.plant_product_group_assignments}},
    child_joins: {PLANT_PRODUCT_GROUP_ASSIGNMENT => "LEFT OUTER JOIN plant_product_group_assignments ON plants.id = plant_product_group_assignments.plant_id"},
  )
  # NOTE: Since we're setting up VENDOR as a full-blown core module based search, it means other variants of Company itself cannot have one, unless further changes are made 
  # to the searching classes in quicksearch_controller, api_core_module_base, application_controller, search_query, search_query_controller_helper (possibly others).
   COMPANY = new("Company","Vendor",
    default_search_columns: [:cmp_name,:cmp_sys_code],
    unique_id_field_name: :cmp_sys_code,
    key_model_field_uids: :cmp_sys_code,
    children: [PLANT],
    child_lambdas: {PLANT => lambda {|c| c.plants}},
    child_joins: {PLANT => "LEFT OUTER JOIN plants plants ON companies.id = plants.company_id"},
    edit_path_proc: Proc.new {|obj| nil},
    view_path_proc: Proc.new {|obj| vendor_path(obj)},
    quicksearch_lambda: lambda {|user, scope| scope.where(Company.search_where(user))},
    enabled_lambda: lambda { MasterSetup.get.vendor_management_enabled? },
    quicksearch_fields: [:cmp_name]
  )

  DRAWBACK_CLAIM = new("DrawbackClaim", "Drawback Claim",
    default_search_columns: [:dc_name, :dc_imp_name, :dc_exports_start_date, :dc_exports_end_date],
    unique_id_field_name: :dc_name,
    key_model_field_uids: [:dc_name],
    children: [],
    child_lambdas: {},
    child_joins: {},
    enabled_lambda: lambda { MasterSetup.get.drawback_enabled? }
  )

  CORE_MODULES = [ORDER,SHIPMENT,PRODUCT,SALE,DELIVERY,ORDER_LINE,SHIPMENT_LINE,DELIVERY_LINE,SALE_LINE,TARIFF,
    CLASSIFICATION,OFFICIAL_TARIFF,ENTRY,BROKER_INVOICE,BROKER_INVOICE_LINE,COMMERCIAL_INVOICE,COMMERCIAL_INVOICE_LINE,COMMERCIAL_INVOICE_TARIFF,
    SECURITY_FILING,SECURITY_FILING_LINE,COMPANY,PLANT,PLANT_PRODUCT_GROUP_ASSIGNMENT,DRAWBACK_CLAIM]

  def self.add_virtual_identifier
    # Add in the virtual_identifier field that is needed for update_model_field_attribute support
    # This field is explained in the UpdateModelFieldsSupport module.
    # It's only here becuase I couldn't figure out a way to meta-program it into that module and make sure
    # the field was added to all child core modules as well.

    # This appears to have to be done outside the CoreModule constructors becuase of the circular reference
    # to CoreModule inside the core module classes (.ie Product, Entry, etc)
    CORE_MODULES.each {|cm| cm.klass.class_eval{attr_accessor :virtual_identifier unless self.respond_to?(:virtual_identifier=)}}
  end
  private_class_method :add_virtual_identifier

  add_virtual_identifier

  def self.set_default_module_chain(core_module, core_module_array)
    mc = ModuleChain.new
    mc.add_array core_module_array
    core_module.default_module_chain = mc
  end

  set_default_module_chain ORDER, [ORDER,ORDER_LINE]
  set_default_module_chain SHIPMENT, [SHIPMENT,SHIPMENT_LINE]
  set_default_module_chain PRODUCT, [PRODUCT, CLASSIFICATION, TARIFF]
  set_default_module_chain SALE, [SALE,SALE_LINE]
  set_default_module_chain DELIVERY, [DELIVERY,DELIVERY_LINE]
  set_default_module_chain ENTRY, [ENTRY,COMMERCIAL_INVOICE,COMMERCIAL_INVOICE_LINE,COMMERCIAL_INVOICE_TARIFF]
  set_default_module_chain BROKER_INVOICE, [BROKER_INVOICE,BROKER_INVOICE_LINE]
  set_default_module_chain SECURITY_FILING, [SECURITY_FILING,SECURITY_FILING_LINE]
  set_default_module_chain COMPANY, [COMPANY, PLANT, PLANT_PRODUCT_GROUP_ASSIGNMENT]

  def self.find_by_class_name(c,case_insensitive=false)
    CORE_MODULES.each do|m|
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
    inner_opts = {:core_modules => CORE_MODULES, :filter=>lambda {|f| true}}.merge(opts)
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
    CORE_MODULES.each {|c| r << c if yield c}
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
