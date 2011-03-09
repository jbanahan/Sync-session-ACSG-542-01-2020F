class CoreModule
  attr_reader :class_name, :label, :table_name,
      :new_object_lambda, 
      :children, #array of child CoreModules used for :has_many (not for :belongs_to)
      :child_lambdas, #hash of lambdas to access child CoreModule data 
      :child_joins, #hash of join statements to link up child CoreModule to parent
      :statusable, #works with status rules
      :worksheetable, #works with worksheet uploads
      :file_formatable, #can be used for file formats
      :make_default_search_lambda #make the search setup that a user will see before they customize
  attr_accessor :default_module_chain #default module chain for searches, needs to be read/write because all CoreModules need to be initialized before setting
  
  def initialize(class_name,label,opts={})
    o = {:worksheetable => false, :statusable=>false, :file_format=>false, 
        :new_object => lambda {Kernel.const_get(class_name).new},
        :children => [], :make_default_search => lambda {|user|
          ss = SearchSetup.create(:name=>"Default",:user => user,:module_type=>class_name,:simple=>false,:last_accessed=>Time.now)
          model_fields.keys.each_with_index do |uid,i|
            ss.search_columns.create(:rank=>i,:model_field_uid=>uid) if i < 3
          end
          ss
        }
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
    @make_default_search_lambda = o[:make_default_search]
  end
  
  def default_module_chain
    return @default_module_chain unless @default_module_chain.nil?
    @default_module_chain = ModuleChain.new
    @default_module_chain.add self
  end
  
  def make_default_search(user)
    @make_default_search_lambda.call(user)
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
  
  #hash of model_fields keyed by UID
  def model_fields
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
    
  ORDER_LINE = new("OrderLine","Order Line") 
  ORDER = new("Order","Order",
    {:file_formatable=>true,
      :children => [ORDER_LINE],
      :child_lambdas => {ORDER_LINE => lambda {|parent| parent.order_lines}},
      :child_joins => {ORDER_LINE => "LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id"},
      :make_default_search => lambda {|user| 
        uids = [:ord_ord_num,:ord_ord_date,:ord_ven_name,:ordln_puid,:ordln_ordered_qty]
        SearchSetup.create_with_columns(uids,user)
      }
    })
  SHIPMENT = new("Shipment","Shipment",
    {:make_default_search => lambda {|user| SearchSetup.create_with_columns([:shp_ref,:shp_mode,:shp_ven_name,:shp_car_name],user)}})
  SALE = new("SalesOrder","Sale",
    {:make_default_search => lambda {|user| SearchSetup.create_with_columns([:sale_order_number,:sale_order_date,:sale_cust_name],user)}})
  DELIVERY = new("Delivery","Delivery",
    {:make_default_search => lambda {|user| SearchSetup.create_with_columns([:del_ref,:del_mode,:del_car_name,:del_cust_name],user)}})
  TARIFF = new("TariffRecord","Tariff")
  CLASSIFICATION = new("Classification","Classification",{
      :children => [TARIFF],
      :child_lambdas => {TARIFF => lambda {|p| p.tariff_records}},
      :child_joins => {TARIFF => "LEFT OUTER JOIN tariff_records ON classifications.id = tariff_records.classification_id"}
  })
  PRODUCT = new("Product","Product",{:statusable=>true,:file_formatable=>true,:worksheetable=>true,
      :children => [CLASSIFICATION],
      :child_lambdas => {CLASSIFICATION => lambda {|p| p.classifications}},
      :child_joins => {CLASSIFICATION => "LEFT OUTER JOIN classifications ON products.id = classifications.product_id"},
      :make_default_search => lambda {|user| SearchSetup.create_with_columns([:prod_uid,:prod_name,:prod_ven_name],user)}
  })
  CORE_MODULES = [ORDER,SHIPMENT,PRODUCT,SALE,DELIVERY,ORDER_LINE]

  def self.set_default_module_chain(core_module, core_module_array)
    mc = ModuleChain.new
    mc.add_array core_module_array
    core_module.default_module_chain = mc
  end

  set_default_module_chain ORDER, [ORDER,ORDER_LINE]
  set_default_module_chain PRODUCT, [PRODUCT, CLASSIFICATION, TARIFF]
  
  def self.find_by_class_name(c)
    CORE_MODULES.each do|m|
    	return m if m.class_name == c
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
