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
      :changed_at_parents_lambda #lambda returning array of objects that should have their changed_at value updated on this module's object's after_save triggers
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
        :bulk_actions_lambda => lambda {|current_user| return Hash.new},
        :changed_at_parents_lambda => lambda {|base_object| []},
        :show_field_prefix => false
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
    SearchSetup.create_with_columns(@default_search_columns,user)
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
    Kernel.const_get(class_name).find id 
  end
  
  #hash of model_fields keyed by UID
  def model_fields
    ModelField.reload_if_stale
    ModelField::MODEL_FIELDS[@class_name.to_sym]
  end
  
  #hash of model_fields for core_module and any core_modules referenced as children
  #and their children recursively
  def model_fields_including_children
    r = model_fields
    @children.each do |c|
      r = r.merge c.model_fields_including_children
    end
    r
  end
  
  def child_objects(child_core_module,base_object)
    @child_lambdas[child_core_module].call(base_object)
  end

  #how many steps away is the given module from this one in the parent child tree
  def module_level(core_module)
    CoreModule.recursive_module_level(0,self,core_module)      
  end
    
  ORDER_LINE = new("OrderLine","Order Line",:show_field_prefix=>true) 
  ORDER = new("Order","Order",
    {:file_formatable=>true,
      :children => [ORDER_LINE],
      :child_lambdas => {ORDER_LINE => lambda {|parent| parent.order_lines}},
      :child_joins => {ORDER_LINE => "LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id"},
      :default_search_columns => [:ord_ord_num,:ord_ord_date,:ord_ven_name,:ordln_puid,:ordln_ordered_qty]
    })
  SHIPMENT_LINE = new("ShipmentLine", "Shipment Line",:show_field_prefix=>true)
  SHIPMENT = new("Shipment","Shipment",
    {:children=>[SHIPMENT_LINE],
    :child_lambdas => {SHIPMENT_LINE => lambda {|p| p.shipment_lines}},
    :child_joins => {SHIPMENT_LINE => "LEFT OUTER JOIN shipment_lines on shipments.id = shipment_lines.shipment_id"},
    :default_search_columns => [:shp_ref,:shp_mode,:shp_ven_name,:shp_car_name]})
  SALE_LINE = new("SalesOrderLine","Sale Line",:show_field_prefix=>true)
  SALE = new("SalesOrder","Sale",
    {:children => [SALE_LINE],
      :child_lambdas => {SALE_LINE => lambda {|parent| parent.sales_order_lines}},
      :child_joins => {SALE_LINE => "LEFT OUTER JOIN sales_order_lines ON sales_orders.id = sales_order_lines.sales_order_id"},
      :default_search_columns => [:sale_order_number,:sale_order_date,:sale_cust_name]
    })
  DELIVERY_LINE = new("DeliveryLine","Delivery Line",:show_field_prefix=>true)
  DELIVERY = new("Delivery","Delivery",
    {:children=>[DELIVERY_LINE],
    :child_lambdas => {DELIVERY_LINE => lambda {|p| p.delivery_lines}},
    :child_joins => {DELIVERY_LINE => "LEFT OUTER JOIN delivery_lines on deliveries.id = delivery_lines.delivery_id"},
    :default_search_columns => [:del_ref,:del_mode,:del_car_name,:del_cust_name]
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
    :show_field_prefix=>true
  })
  CLASSIFICATION = new("Classification","Classification",{
      :children => [TARIFF],
      :child_lambdas => {TARIFF => lambda {|p| p.tariff_records}},
      :child_joins => {TARIFF => "LEFT OUTER JOIN tariff_records ON classifications.id = tariff_records.classification_id"},
      :changed_at_parents_lambda=>lambda {|c| c.product.nil? ? [] : [c.product] },
      :show_field_prefix=>true
  })
  PRODUCT = new("Product","Product",{:statusable=>true,:file_formatable=>true,:worksheetable=>true,
      :children => [CLASSIFICATION],
      :child_lambdas => {CLASSIFICATION => lambda {|p| p.classifications}},
      :child_joins => {CLASSIFICATION => "LEFT OUTER JOIN classifications ON products.id = classifications.product_id"},
      :default_search_columns => [:prod_uid,:prod_name,:prod_ven_name],
      :bulk_actions_lambda => lambda {|current_user| 
        bulk_actions = {}
        bulk_actions["Edit Selected"]='bulk_edit_products_path' if current_user.edit_products?
        bulk_actions["Classify Selected"]='bulk_classify_products_path' if current_user.edit_classifications?
        bulk_actions
      },
      :changed_at_parents_lambda=>lambda {|p| [p]} #only update self
  })
  OFFICIAL_TARIFF = new("OfficialTariff","HTS Regulation",:default_search_columns=>[:ot_hts_code,:ot_full_desc,:ot_gen_rate])
  CORE_MODULES = [ORDER,SHIPMENT,PRODUCT,SALE,DELIVERY,ORDER_LINE,SHIPMENT_LINE,DELIVERY_LINE,SALE_LINE,TARIFF,CLASSIFICATION,OFFICIAL_TARIFF]

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
  def self.grouped_options
    r = {}
    mods = [ORDER,SHIPMENT,PRODUCT,SALE,DELIVERY,ORDER_LINE,SHIPMENT_LINE,DELIVERY_LINE,SALE_LINE,TARIFF,CLASSIFICATION].sort {|x,y| x.label <=> y.label}
    mods.each do |cm|
      flds = cm.model_fields.values.sort {|x,y| x.label <=> y.label}
      fld_array = []
      flds.each {|f| fld_array << [f.label,f.uid]}
      r[cm.label] = fld_array
    end
    r
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
