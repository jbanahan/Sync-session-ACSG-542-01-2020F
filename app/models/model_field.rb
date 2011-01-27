class ModelField
  attr_reader :model, :field_name, :label, :sort_rank, 
              :import_lambda, :export_lambda, 
              :custom_id, :data_type, :core_module, 
              :join_statement, :join_alias, :uid
  
  def initialize(rank,uid,core_module, field, label, options={})
    o = {:import_lambda =>  lambda {|obj,data|
           obj.send("#{@field_name}=".intern,data)
           return "#{@label} set to #{data}"
          },
          :export_lambda => lambda {|obj|
            if self.custom?
            obj.get_custom_value(CustomDefinition.find(@custom_id)).value
            else
              obj.send("#{@field_name}")
            end
          },
        }.merge(options)
    @uid = uid
    @core_module = core_module
    @sort_rank = rank
    @model = core_module.class_name.intern
    @field_name = field
    @label = label
    @import_lambda = o[:import_lambda]
    @export_lambda = o[:export_lambda]
    @custom_id = o[:custom_id]
    @join_statement = o[:join_statement]
    @join_alias = o[:join_alias]
    @data_type = determine_data_type
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
  def process_import(obj,data)
    @import_lambda.call(obj,data)
  end

  def process_export(obj)
    obj.nil? ? '' : @export_lambda.call(obj)
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
      mf = ModelField.new(m[0],m[1],core_module,m[2],m[3],m[4].nil? ? {} : m[4])
      MODEL_FIELDS[module_type][mf.uid.to_sym] = mf
    end
  end 
  
  add_fields CoreModule::PRODUCT, [
    [1,:prod_uid,:unique_identifier,"Unique Identifier"],
    [2,:prod_div_id,:division_id,"Division ID"],
    [3,:prod_name,:name,"Name"],
    [4,:prod_uom,:unit_of_measure,"Unit of Measure"],
    [5,:prod_ven_id,:vendor_id,"Vendor ID"],
    [6,:prod_ven_name, :name,"Vendor Name", {
      :import_lambda => lambda {|detail,data|
        vendor = Company.where(:name => data).where(:vendor => true).first
        detail.vendor = vendor
        unless vendor.nil?
          return "Vendor set to #{vendor.name}"
        else
          return "Vendor not found with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| detail.vendor.name},
      :join_statement => "LEFT OUTER JOIN companies AS prod_vend_comp on prod_vend_comp.id = products.vendor_id",
      :join_alias => "prod_vend_comp"
    }],
    [7,:prod_status_name, :name, "Status", {
      :import_lambda => lambda {|detail,data|
        status = StatusRule.where(:name => data).where(:module_type => CoreModule::PRODUCT.class_name)
        detail.status_rule = status
        unless status.nil?
          return "Status set to #{status.name}"
        else
          return "Status not found with name \"#{data}\""
        end 
      },
      :export_lambda => lambda {|detail| detail.status_rule.nil? ? "" : detail.status_rule.name },
      :join_statement => "LEFT OUTER JOIN status_rules AS prod_status_name ON  prod_status_name.id = products.status_rule_id",
      :join_alias => "prod_status_name"
    }],
    [9,:prod_div_name, :name, "Division Name", {
      :import_lambda => lambda {|obj,data|
        div = Division.where(:name=>data)
        obj.division = div unless div.nil?
        unless div.nil?
          return "Division set to #{div.name}"
        else
          return "Division with name \"#{data}\" not found"
        end
      },
      :export_lambda => lambda {|obj| obj.division.nil? ? "" : obj.division.name },
      :join_statment => "LEFT OUTER JOIN divisions AS prod_div_name ON prod_div_name.id = products.division_id",
      :join_alias => "prod_div_name"
    }]
  ]
    
  add_fields CoreModule::ORDER, [
    [1,:ord_ord_num,:order_number,"Header - Order Number"],
    [2,:ord_ord_date,:order_date,"Header - Order Date"],
    [5,:ord_ven_id,:vendor_id,"Header - Vendor ID"]
  ]
  
  add_fields CoreModule::ORDER_LINE, [
    [1,:ordln_line_number,:line_number,"Line - Line Number"],
    [2,:ordln_puid,:unique_identifier,"Line - Product Unique Identifier",{
      :import_lambda => lambda {|detail,data|
        detail.product = Product.where(:unique_identifier => data).first
        return "Line #{detail.line_number} - Product set to #{data}"
      },
      :export_lambda => lambda {|detail|
        detail.product.unique_identifier
      },
      :join_statement => "LEFT OUTER JOIN products AS ordln_puid ON ordln_puid.id = order_lines.product_id",
      :join_alias => "ordln_puid"
    }],
    [3,:ordln_ordered_qty,:ordered_qty,"Line - Order Quantity"],
    [4,:ordln_ppu,:price_per_unit,"Line - Price / Unit"]
  ]
  add_fields CoreModule::SHIPMENT, [
    [1,:shp_ref,:reference,"Reference Number"],
    [2,:shp_mode,:mode,"Mode"],
    [3,:shp_ven_id,:vendor_id,"Vendor ID"],
    [4,:shp_car_id,:carrier_id,"Carrier ID"],
    [5,:shp_sf_id,:ship_from_id,"Ship From ID"],
    [6,:shp_st_id,:ship_to_id,"Ship To ID"]
  ]
  
  add_fields CoreModule::SALE, [
    [1,:sale_order_number,:order_number,"Header - Order Number"],
    [2,:sale_order_date,:order_date,"Header - Order Date"],
    [3,:sale_cust_id,:customer_id,"Header - Customer ID"],
    [4,:sale_comm,:comments,"Header - Comments"],
    [5,:sale_div_id,:division_id,"Header - Division ID"],
    [6,:sale_st_id,:ship_to_id,"Header - Ship To ID"]
  ]
  
  add_fields CoreModule::DELIVERY, [
    [1,:del_ref,:reference,"Reference"],
    [2,:del_mode,:mode,"Mode"],
    [3,:del_sf_id,:ship_from_id,"Ship From ID"],
    [4,:del_st_id,:ship_to_id,"Ship To ID"],
    [5,:del_car_id,:carrier_id,"Carrier ID"],
    [6,:del_cust_id,:customer_id,"Customer ID"]
  ]

  def self.add_custom_fields(core_module,base_class,label_prefix,parameters={})
    max = 0
    m_type = core_module.class_name.intern
    model_hash = MODEL_FIELDS[m_type]
    model_hash.values.each {|mf| max = mf.sort_rank + 1 if mf.sort_rank > max}
    base_class.new.custom_definitions.each_with_index do |d,index|
      class_symbol = base_class.to_s.downcase
      fld = "*cf_#{d.id}".intern
      mf = ModelField.new(max+index,fld,core_module,fld,"#{label_prefix}#{d.label}",parameters.merge({:custom_id=>d.id}))
      model_hash[mf.uid.to_sym] = mf
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
      u = uid.to_sym
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
