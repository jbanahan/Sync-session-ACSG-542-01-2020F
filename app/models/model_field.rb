class ModelField
  attr_reader :model, :field_name, :label, :sort_rank, 
              :import_lambda, :export_lambda, 
              :custom_id, :data_type, :core_module, 
              :join_statement, :join_alias, :qualified_field_name, :uid, 
              :public, :public_searchable
  
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
    @model = core_module.class_name.intern unless core_module.nil?
    @field_name = field
    @label = label
    @import_lambda = o[:import_lambda]
    @export_lambda = o[:export_lambda]
    @custom_id = o[:custom_id]
    @join_statement = o[:join_statement]
    @join_alias = o[:join_alias]
    @data_type = o[:data_type].nil? ? determine_data_type : o[:data_type]
    pf = PublicField.where(:model_field_uid => @uid)
    @public = !pf.empty?
    @public_searchable = @public && pf.first.searchable
    @qualified_field_name = o[:qualified_field_name]
  end
  

  def qualified_field_name
    @qualified_field_name.nil? ? "#{self.join_alias}.#{@field_name}" : @qualified_field_name
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
  
  def public?
    @public
  end
  def public_searchable?
    @public_searchable
  end
  
  def determine_data_type
    if @custom_id.nil?
      return Kernel.const_get(@model).columns_hash[@field_name.to_s].klass.to_s.downcase.to_sym
    else
      return CustomDefinition.find(@custom_id).data_type.downcase.to_sym
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
  
  def self.make_division_arrays(rank_start,uid_prefix,label_prefix,table_name)
    r = [
      [rank_start,"#{uid_prefix}_div_id".to_sym,:division_id,"#{label_prefix}Division ID"]
    ]
    n = [rank_start+1,"#{uid_prefix}_div_name".to_sym, :name,"#{label_prefix}Division Name",{
      :import_lambda => lambda {|obj,data|
        d = Division.where(:name => data).first
        obj.division = d
        unless d.nil?
          return "Division set to #{d.name}"
        else
          return "Division not found with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|obj| obj.division.nil? ? "" : obj.division.name},
      :join_statement => "LEFT OUTER JOIN divisions AS #{table_name}_div on #{table_name}_div.id = #{table_name}.division_id",
      :join_alias => "#{table_name}_div",
      :data_type => :string
    }]
    r << n
    r
  end
  def self.make_carrier_arrays(rank_start,uid_prefix,label_prefix,table_name)
    r = [
      [rank_start,"#{uid_prefix}_car_id".to_sym,:carrier_id,"#{label_prefix}Carrier ID"]
    ]
    r << [rank_start+1,"#{uid_prefix}_car_name".to_sym, :name,"#{label_prefix}Carrier Name",{
      :import_lambda => lambda {|obj,data|
        carrier = Company.where(:name => data).where(:carrier => true).first
        unless carrier.nil?
          obj.carrier = carrier
          return "Carrier set to #{carrier.name}"
        else
          carrier = Company.create(:name=>data,:carrier=>true)
          obj.carrier = carrier
          return "Carrier auto-created with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|obj| obj.carrier.nil? ? "" : obj.carrier.name},
      :join_statement => "LEFT OUTER JOIN companies AS #{table_name}_car_comp on #{table_name}_car_comp.id = #{table_name}.carrier_id",
      :join_alias => "#{table_name}_car_comp",
      :data_type => :string
    }]
    r << [rank_start+2,"#{uid_prefix}_car_syscode".to_sym,:system_code,"#{label_prefix}Carrier System Code", {
      :import_lambda => lambda {|obj,data|
        carrier = Company.where(:system_code=>data,:carrier=>true).first
        obj.carrier = carrier
        unless carrier.nil?
          return "Carrier set to #{carrier.name}"
        else
          return "Carrier not found with code \"#{data}\""
        end
      },
      :export_lambda => lambda {|o| o.carrier.nil? ? "" : o.carrier.system_code},
      :join_statement => "LEFT OUTER JOIN companies AS #{table_name}_car_comp on #{table_name}_car_comp.id = #{table_name}.carrier_id",
      :join_alias => "#{table_name}_car_comp",
      :data_type=>:string
    }]
    r
  end
  def self.make_customer_arrays(rank_start,uid_prefix,label_prefix,table_name) 
    r = [
      [rank_start,"#{uid_prefix}_cust_id".to_sym,:customer_id,"#{label_prefix}Customer ID"]
    ]
    r << [rank_start+1,"#{uid_prefix}_cust_name".to_sym, :name,"#{label_prefix}Customer Name", {
      :import_lambda => lambda {|detail,data|
        c = Company.where(:name => data).where(:customer => true).first
        unless c.nil?
          detail.customer = c
          return "Customer set to #{c.name}"
        else
          customer = Company.create(:name=>data,:customer=>true)
          detail.customer = customer
          return "Customer auto-created with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| detail.customer.nil? ? "" : detail.customer.name},
      :join_statement => "LEFT OUTER JOIN companies AS #{table_name}_cust_comp on #{table_name}_cust_comp.id = #{table_name}.customer_id",
      :join_alias => "#{table_name}_cust_comp",
      :data_type=>:string
    }]
    r << [rank_start+2,"#{uid_prefix}_cust_syscode".to_sym,:system_code,"#{label_prefix}Customer System Code", {
      :import_lambda => lambda {|o,data|
        customer = Company.where(:system_code=>data,:customer=>true).first
        o.customer = customer
        unless customer.nil?
          return "Customer set to #{customer.name}"
        else
          return "Customer not found with code \"#{data}\""
        end
      },
      :export_lambda => lambda {|o| o.customer.nil? ? "" : o.customer.system_code},
      :join_statement => "LEFT OUTER JOIN companies AS #{table_name}_cust_comp on #{table_name}_cust_comp.id = #{table_name}.customer_id",
      :join_alias => "#{table_name}_car_comp",
      :data_type=>:string
    }]
    r
  end
  def self.make_vendor_arrays(rank_start,uid_prefix,label_prefix,table_name) 
    r = [
      [rank_start,"#{uid_prefix}_ven_id".to_sym,:vendor_id,"#{label_prefix}Vendor ID"]
    ]
    r << [rank_start+1,"#{uid_prefix}_ven_name".to_sym, :name,"#{label_prefix}Vendor Name", {
      :import_lambda => lambda {|detail,data|
        vendor = Company.where(:name => data).where(:vendor => true).first
        unless vendor.nil?
          detail.vendor = vendor
          return "Vendor set to #{vendor.name}"
        else
          vendor = Company.create(:name=>data,:vendor=>true)
          detail.vendor = vendor
          return "Vendor auto-created with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| detail.vendor.nil? ? "" : detail.vendor.name},
      :join_statement => "LEFT OUTER JOIN companies AS #{table_name}_vend_comp on #{table_name}_vend_comp.id = #{table_name}.vendor_id",
      :join_alias => "#{table_name}_vend_comp",
      :data_type=>:string
    }]
    r << [rank_start+2,"#{uid_prefix}_ven_syscode".to_sym,:system_code,"#{label_prefix}Vendor System Code", {
      :import_lambda => lambda {|o,data|
        vendor = Company.where(:system_code=>data,:vendor=>true).first
        unless vendor.nil?
          o.vendor = vendor
          return "Vendor set to #{vendor.name}"
        else
          return "Vendor not found with code \"#{data}\""
        end
      },
      :export_lambda => lambda {|o| o.vendor.nil? ? "" : o.vendor.system_code},
      :join_statement => "LEFT OUTER JOIN companies AS #{table_name}_ven_comp on #{table_name}_ven_comp.id = #{table_name}.vendor_id",
      :join_alias => "#{table_name}_ven_comp",
      :data_type => :string
    }]
    r
  end

  #Don't use this.  Use make_ship_from_arrays or make_ship_to_arrays
  def self.make_ship_arrays(rank_start,uid_prefix,label_prefix,table_name,ft)
    raise "Invalid shipping from/to indicator provided: #{ft}" unless ["from","to"].include?(ft)
    ftc = ft.titleize
    r = [
      [rank_start,"#{uid_prefix}_ship_#{ft}_id".to_sym,"ship_#{ft}_id".to_sym,"#{label_prefix}Ship #{ftc} ID"]
    ]
    n = [rank_start+1,"#{uid_prefix}_ship_#{ft}_name".to_sym,:name,"#{label_prefix}Ship #{ftc} Name", {
      :import_lambda => lambda {|obj,data|
        a = Address.where(:name=>data).where(:shipping => true).first
        if ft=="to"
          obj.ship_to = a
        elsif ft=="from"
          obj.ship_from = a
        end
        unless a.nil?
          return "Ship #{ftc} set to #{a.name}"
        else
          return "Ship #{ftc} not found with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|obj| 
        if ft=="to"
          return obj.ship_to.nil? ? "" : obj.ship_to.name
        elsif ft=="from"
          return obj.ship_from.nil? ? "" : obj.ship_from.name
        end
      },
      :join_statement => "LEFT OUTER JOIN addresses AS #{table_name}_ship_#{ft} on #{table_name}_ship_#{ft}.id = #{table_name}.ship_#{ft}_id",
      :join_alias => "#{table_name}_ship_#{ft}",
      :data_type=>:string
    }]
    r << n
    r
  end
  
  def self.make_ship_to_arrays(rank_start,uid_prefix,label_prefix,table_name)
    make_ship_arrays(rank_start,uid_prefix,label_prefix,table_name,"to")
  end
  def self.make_ship_from_arrays(rank_start,uid_prefix,label_prefix,table_name)
    make_ship_arrays(rank_start,uid_prefix,label_prefix,table_name,"from")
  end
  def self.make_country_arrays(rank_start,uid_prefix,label_prefix,table_name)
    r = []
    r << [rank_start,"#{uid_prefix}_cntry_name".to_sym, :name,"#{label_prefix}Country Name", {
      :import_lambda => lambda {|detail,data|
        c = Country.where(:name => data).first
        detail.country = c
        unless c.nil?
          return "Country set to #{c.name}"
        else
          return "Country not found with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| detail.country.nil? ? "" : detail.country.name},
      :join_statement => "LEFT OUTER JOIN countries AS #{table_name}_country on #{table_name}_country.id = #{table_name}.country_id",
      :join_alias => "#{table_name}_country",
      :data_type=>:string
    }]
    r << [rank_start+1,"#{uid_prefix}_cntry_iso".to_sym, :iso_code, "#{label_prefix}Country ISO Code",{
      :import_lambda => lambda {|detail,data|
        c = Country.where(:iso_code => data).first
        detail.country = c
        unless c.nil?
          return "Country set to #{c.name}"
        else
          return "Country not found with ISO Code \"#{data}\""
        end    
      },
      :export_lambda => lambda {|detail| detail.country.nil? ? "" : detail.country.iso_code},
      :join_statement => "LEFT OUTER JOIN countries AS #{table_name}_country on #{table_name}_country.id = #{table_name}.country_id",
      :join_alias => "#{table_name}_country",
      :data_type=>:string  
    }]
    r
  end
  def self.make_product_arrays(rank_start,uid_prefix,label_prefix,table_name)
    r = []
    r << [rank_start,"#{uid_prefix}_puid".to_sym, :unique_identifier,"#{label_prefix}Product Unique ID", {
      :import_lambda => lambda {|detail,data|
        p = Product.where(:unique_identifier=>data).first
        return "Product not found with unique identifier #{data}" if p.nil?
        detail.product = p
        return "Product set to #{data}"
      },
      :export_lambda => lambda {|detail|
        if detail.product
          return detail.product.unique_identifier
        else
          return nil
        end
      },
      :join_statement => "LEFT OUTER JOIN products AS #{uid_prefix}_puid ON #{uid_prefix}_puid.id = #{table_name}.product_id",
      :join_alias => "#{uid_prefix}_puid",:data_type=>:string
    }]
    r << [rank_start+1,"#{uid_prefix}_pname".to_sym, :name,"#{label_prefix}Product Name",{
      :import_lambda => lambda {|detail,data|
        prods = Product.where(:name=>data)
        if prods.size>1
          return "Multiple products found with name #{data}, field ignored."
        elsif prods.size==0
          return "Product not found with name #{data}"
        else
          detail.product = prods.first
          return "Product set to #{data}"
        end
      },
      :export_lambda => lambda {|detail|
        if detail.product
          return detail.product.name
        else
          return nil
        end
      },
      :join_statement => "LEFT OUTER JOIN products AS #{uid_prefix}_pname ON #{uid_prefix}_pname.id = #{table_name}.product_id",
      :join_alias => "#{uid_prefix}_pname",:data_type=>:string
    }]
    r
  end

  def self.add_custom_fields(core_module,base_class,label_prefix,parameters={})
    max = 0
    m_type = core_module.class_name.intern
    model_hash = MODEL_FIELDS[m_type]
    model_hash.values.each {|mf| max = mf.sort_rank + 1 if mf.sort_rank > max}
    base_class.new.custom_definitions.order("rank ASC").each_with_index do |d,index|
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
    ModelField.add_custom_fields(CoreModule::CLASSIFICATION,Classification,"Classification - ")
    ModelField.add_custom_fields(CoreModule::SHIPMENT,Shipment,"Header - ")
    ModelField.add_custom_fields(CoreModule::SHIPMENT_LINE,ShipmentLine,"Line - ")
    ModelField.add_custom_fields(CoreModule::SALE,SalesOrder,"Header - ")
    ModelField.add_custom_fields(CoreModule::SALE_LINE,SalesOrderLine,"Line - ")
    ModelField.add_custom_fields(CoreModule::DELIVERY,Delivery,"")
  end
  def self.reload 
    add_fields CoreModule::PRODUCT, [
      [1,:prod_uid,:unique_identifier,"Unique Identifier",{:data_type=>:string}],
      #2 is available to use
      [3,:prod_name,:name,"Name",{:data_type=>:string}],
      [4,:prod_uom,:unit_of_measure,"Unit of Measure",{:data_type=>:string}],
      #5 and 6 are now created with the make_vendor_arrays method below, Don't use them.
      [7,:prod_status_name, :name, "Status", {
        :import_lambda => lambda {|detail,data|
          return "Statuses are ignored. They are automatically calculated."
        },
        :export_lambda => lambda {|detail| detail.status_rule.nil? ? "" : detail.status_rule.name },
        :join_statement => "LEFT OUTER JOIN status_rules AS prod_status_name ON  prod_status_name.id = products.status_rule_id",
        :join_alias => "prod_status_name",
        :data_type=>:string
      }],
      #9 is available to use
      [10,:prod_class_count, :class_count, "Complete Classification Count", {
        :import_lambda => lambda {|obj,data|
          return "Complete Classification Count was ignored. (read only)"},
        :export_lambda => lambda {|obj| 
          r = 0
          obj.classifications.each {|c| 
            r += 1 if c.tariff_records.length > 0
          }
          r
        },
        :join_statement => "LEFT OUTER JOIN (SELECT COUNT(id) as class_count, product_id FROM classifications WHERE classifications.id IN (select classification_id from tariff_records) group by product_id) as prod_class_count ON prod_class_count.product_id = products.id",
        :join_alias => "prod_class_count",
        :qualified_field_name => "ifnull(prod_class_count.class_count,0)",
        :data_type => :integer
      }]
    ]
    add_fields CoreModule::PRODUCT, make_vendor_arrays(5,"prod","","products")
    add_fields CoreModule::PRODUCT, make_division_arrays(100,"prod","","products")
    
    add_fields CoreModule::CLASSIFICATION, make_country_arrays(100,"class","Classification - ","classifications")

    add_fields CoreModule::TARIFF, [
      [1,:hts_hts_1,:hts_1,"Tariff - HTS 1"],
      [2,:hts_hts_2,:hts_2,"Tariff - HTS 2"],
      [3,:hts_hts_3,:hts_3,"Tariff - HTS 3"],
      [4,:hts_line_number,:line_number,"Tariff - Row"]
    ]

    add_fields CoreModule::ORDER, [
      [1,:ord_ord_num,:order_number,"Header - Order Number"],
      [2,:ord_ord_date,:order_date,"Header - Order Date",{:data_type=>:date}],
    ]
    add_fields CoreModule::ORDER, make_vendor_arrays(100,"ord","Header - ","orders")
    add_fields CoreModule::ORDER, make_ship_to_arrays(200,"ord","Header - ","orders")

    add_fields CoreModule::ORDER_LINE, [
      [1,:ordln_line_number,:line_number,"Line - Row",{:data_type=>:integer}],
      [3,:ordln_ordered_qty,:quantity,"Line - Order Quantity",{:data_type=>:decimal}],
      [4,:ordln_ppu,:price_per_unit,"Line - Price / Unit",{:data_type=>:decimal}]
    ]
    add_fields CoreModule::ORDER_LINE, make_product_arrays(100,"ordln","Line - ","order_lines")

    add_fields CoreModule::SHIPMENT, [
      [1,:shp_ref,:reference,"Reference Number",{:data_type=>:string}],
      [2,:shp_mode,:mode,"Mode",{:data_type=>:string}],
    ]
    add_fields CoreModule::SHIPMENT, make_vendor_arrays(100,"shp","Header - ","shipments")
    add_fields CoreModule::SHIPMENT, make_ship_to_arrays(200,"shp","Header - ","shipments")
    add_fields CoreModule::SHIPMENT, make_ship_from_arrays(250,"shp","Header - ","shipments")
    add_fields CoreModule::SHIPMENT, make_carrier_arrays(300,"shp","Header - ","shipments")
    
    add_fields CoreModule::SHIPMENT_LINE, [
      [1,:shpln_line_number,:line_number,"Line - Row",{:data_type=>:integer}],
      [2,:shpln_shipped_qty,:quantity,"Line - Ship Quantity",{:data_type=>:decimal}]
    ]
    add_fields CoreModule::SHIPMENT_LINE, make_product_arrays(100,"shpln","Line - ","shipment_lines")


    add_fields CoreModule::SALE, [
      [1,:sale_order_number,:order_number,"Header - Order Number",{:data_type=>:string}],
      [2,:sale_order_date,:order_date,"Header - Order Date",{:data_type=>:date}],
    ]
    add_fields CoreModule::SALE, make_customer_arrays(100,"sale","Header - ","sales_orders")
    add_fields CoreModule::SALE, make_ship_to_arrays(200,"sale","Header - ","sales_orders")
    add_fields CoreModule::SALE, make_division_arrays(300,"sale","Heade - ","sales_orders")

    add_fields CoreModule::SALE_LINE, [
      [1,:soln_line_number,:line_number,"Line - Row", {:data_type=>:integer}],
      [3,:soln_ordered_qty,:quantity,"Line - Order Quantity",{:data_type=>:decimal}],
      [4,:soln_ppu,:price_per_unit,"Line - Price / Unit",{:data_type => :decimal}]
    ]
    add_fields CoreModule::SALE_LINE, make_product_arrays(100,"soln","Line - ","sale_order_lines")
    
    add_fields CoreModule::DELIVERY, [
      [1,:del_ref,:reference,"Reference",{:data_type=>:string}],
      [2,:del_mode,:mode,"Mode",{:data_type=>:string}],
    ]
    add_fields CoreModule::DELIVERY, make_ship_from_arrays(100,"del","","deliveries")
    add_fields CoreModule::DELIVERY, make_ship_to_arrays(200,"del","","deliveries")
    add_fields CoreModule::DELIVERY, make_carrier_arrays(300,"del","","deliveries")
    add_fields CoreModule::DELIVERY, make_customer_arrays(400,"del","","deliveries")

    add_fields CoreModule::DELIVERY_LINE, [
      [1,:delln_line_number,:line_number,"Line - Row",{:data_type=>:integer}],
      [2,:delln_delivery_qty,:quantity,"Line - Delivery Qauntity",{:data_type=>:decimal}]
    ]
    add_fields CoreModule::DELIVERY_LINE, make_product_arrays(100,"delln","Line - ","delivery_lines")
    reset_custom_fields
  end

  reload

  def self.find_by_uid(uid)
    return ModelField.new(10000,:_blank,nil,nil,"[blank]",{
      :import_lambda => lambda {|o,d| "Field ignored"},
      :export_lambda => lambda {|o| },
      :data_type => :string
    }) if uid.to_sym == :_blank
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

end
