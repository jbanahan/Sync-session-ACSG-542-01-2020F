class ModelField
  attr_reader :model, :field_name, :label, :sort_rank, 
              :import_lambda, :export_lambda, 
              :custom_id, :data_type, :core_module
  
  def initialize(rank,core_module, field, label, options={})
    @core_module = core_module
    @sort_rank = rank
    @model = core_module.class_name.intern
    @field_name = field
    @label = label
    @import_lambda = options[:import_lambda].nil? ? lambda {|obj,data|
        obj.send("#{@field_name}=".intern,data)
        return "#{@label} set to #{data}"
      } : options[:import_lambda]
    @export_lambda = options[:export_lambda].nil? ? lambda {|obj|
        if self.custom?
        obj.get_custom_value(CustomDefinition.find(@custom_id)).value
        else
          obj.send("#{@field_name}")
        end
      } : options[:export_lambda]
    @custom_id = options[:custom_id]
    @data_type = determine_data_type
  end
  
    #code to process when importing a field
  def process_import(obj,data)
    @import_lambda.call(obj,data)
  end

  def process_export(obj)
    obj.nil? ? '' : @export_lambda.call(obj)
  end

  def uid
    return "#{@model}-#{@field_name}"
  end

  def custom?
    return !@custom_id.nil?
  end
  
  
  def determine_data_type
    if @custom_id.nil?
      return Kernel.const_get(@model).columns_hash[@field_name.to_s].type
    else
      return CustomDefinition.find(@custom_id).data_type.intern
    end
  end
  
  #should be after all class level methods are declared
  MODEL_FIELDS = Hash.new
  def self.add_fields(core_module,descriptor_array)
    module_type = core_module.class_name.to_sym
    MODEL_FIELDS[module_type] = Hash.new if MODEL_FIELDS[module_type].nil?
    descriptor_array.each do |m|
      mf = ModelField.new(m[0],core_module,m[1],m[2],m[3].nil? ? {} : m[3])
      MODEL_FIELDS[module_type][mf.uid.intern] = mf
    end
  end 
  
  add_fields CoreModule::PRODUCT, [
    [1,:unique_identifier,"Unique Identifier"],
    [2,:division_id,"Division ID"],
    [3,:name,"Name"],
    [5,:vendor_id,"Vendor ID"],
    [6,:vendor_name,"Vendor Name", {
      :import_lambda => lambda {|detail,data|
        vendor = Company.where(:name => data).where(:vendor => true).first
        detail.vendor = vendor
        unless vendor.nil?
          return "Line #{detail.line_number} - Vendor set to #{vendor.name}"
        else
          return "Line #{detail.line_number} - Vendor not found with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| detail.vendor.name}
    }]
  ]
    
  add_fields CoreModule::ORDER, [
    [1,:order_number,"Header - Order Number"],
    [2,:order_date,"Header - Order Date"],
    [5,:vendor_id,"Header - Vendor ID"]
  ]
  
  add_fields CoreModule::ORDER_LINE, [
    [1,:line_number,"Line - Line Number"],
    [2,:product_unique_identifier,"Line - Product Unique Identifier",{
      :import_lambda => lambda {|detail,data|
        detail.product = Product.where(:unique_identifier => data).first
        return "Line #{detail.line_number} - Product set to #{data}"
      },
      :export_lambda => lambda {|detail|
        detail.product.unique_identifier
      }
    }],
    [3,:ordered_qty,"Line - Order Quantity"],
    [4,:price_per_unit,"Line - Price / Unit"]
  ]
  add_fields CoreModule::SHIPMENT, [
    [1,:reference,"Reference Number"],
    [2,:mode,"Mode"],
    [3,:vendor_id,"Vendor ID"],
    [4,:carrier_id,"Carrier ID"],
    [5,:ship_from_id,"Ship From ID"],
    [6,:ship_to_id,"Ship To ID"]
  ]
  
  add_fields CoreModule::SALE, [
    [1,:order_number,"Header - Order Number"],
    [2,:order_date,"Header - Order Date"],
    [3,:customer_id,"Header - Customer ID"],
    [4,:comments,"Header - Comments"],
    [5,:division_id,"Header - Division ID"],
    [6,:ship_to_id,"Header - Ship To ID"]
  ]
  
  add_fields CoreModule::DELIVERY, [
    [1,:reference,"Reference"],
    [2,:mode,"Mode"],
    [3,:ship_from_id,"Ship From ID"],
    [4,:ship_to_id,"Ship To ID"],
    [5,:carrier_id,"Carrier ID"],
    [6,:customer_id,"Customer ID"]
  ]

  def self.add_custom_fields(core_module,base_class,label_prefix,parameters={})
    max = 0
    m_type = core_module.class_name.intern
    model_hash = MODEL_FIELDS[m_type]
    model_hash.values.each {|mf| max = mf.sort_rank + 1 if mf.sort_rank > max}
    base_class.new.custom_definitions.each_with_index do |d,index|
      class_symbol = base_class.to_s.downcase
      mf = ModelField.new(max+index,core_module,"*cf_#{d.id}".intern,"#{label_prefix}#{d.label}",parameters.merge({:custom_id=>d.id}))
      model_hash[mf.uid.intern] = mf
    end
  end
  
  def self.reset_custom_fields
    CoreModule::CORE_MODULES.each do |cm|
      h = MODEL_FIELDS[cm.class_name.to_sym]
      h.each do |k,v|
        h.delete k unless v.custom_id.nil?
      end
    end
    ModelField.add_custom_fields(CoreModule::ORDER,Order,"Header - ")
    ModelField.add_custom_fields(CoreModule::ORDER_LINE,OrderLine,"Line - ")
    ModelField.add_custom_fields(CoreModule::PRODUCT,Product,"")
    ModelField.add_custom_fields(CoreModule::SHIPMENT,Shipment,"")
    ModelField.add_custom_fields(CoreModule::SALE,SalesOrder,"Header - ")
    ModelField.add_custom_fields(CoreModule::DELIVERY,Delivery,"")
  end
  
  reset_custom_fields

  def self.find_by_uid(uid)
    MODEL_FIELDS.values.each do |h|
      u = uid.intern
      return h[u] unless h[u].nil?
    end
    return nil
  end
  
  def self.find_by_module_type(type_symbol)
    h = MODEL_FIELDS[type_symbol]
    h.nil? ? [] : h.values.to_a
  end
  
  def self.find_by_module_type_and_field_name(type_symbol,name_symbol)
    find_by_module_type(type_symbol).each { |mf|
      return mf if mf.field_name == name_symbol
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

end
