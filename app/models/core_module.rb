class CoreModule
  attr_reader :class_name, :label, :table_name,
      :new_object_lambda, 
      :children, #array of child CoreModules used for :has_many (not for :belongs_to)
      :statusable, :file_formatable
  
  def initialize(class_name,label,opts={})
    o = {:statusable=>false, :file_format=>false, 
        :new_object => lambda {Kernel.const_get(class_name).new},
        :children => []
      }.
      merge(opts)
    @class_name = class_name
    @label = label
    @table_name = class_name.underscore.pluralize
    @statusable = o[:statusable]
    @file_formatable = o[:file_formatable]
    @new_object_lambda = o[:new_object]
    @children = o[:children]
  end
  
  #can have status set on the module 
  def statusable?
    @statusable
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
    
  ORDER_LINE = new("OrderLine","Order Line") 
  ORDER = new("Order","Order",
    {:file_formatable=>true,
      :children => [ORDER_LINE]
    })
  SHIPMENT = new("Shipment","Shipment")
  PRODUCT = new("Product","Product",{:statusable=>true,:file_formatable=>true})
  SALE = new("SalesOrder","Sale")
  DELIVERY = new("Delivery","Delivery")
  CORE_MODULES = [ORDER,SHIPMENT,PRODUCT,SALE,DELIVERY,ORDER_LINE]
  
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
=begin    r = []
    CORE_MODULES.each do |m|
      if block_given?
        r << [m.label,m.class_name] if yield m
      else
      	r << [m.label,m.class_name]
      end
    end
    r
=end
  end
  
  private
  def self.test_to_array
    r = []
    CORE_MODULES.each {|c| r << c if yield c}
    r
  end
end