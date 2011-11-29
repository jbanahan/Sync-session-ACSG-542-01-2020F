class ModelField
  @@last_loaded = nil
  attr_reader :model, :field_name, :label_prefix, :sort_rank, 
              :import_lambda, :export_lambda, 
              :custom_id, :data_type, :core_module, 
              :join_statement, :join_alias, :qualified_field_name, :uid, 
              :public, :public_searchable
  
  def initialize(rank,uid,core_module, field, options={})
    o = {:import_lambda =>  lambda {|obj,data|
          d = [:date,:datetime].include?(self.data_type) ? parse_date(data) : data
          obj.send("#{@field_name}=".intern,d)
          return "#{FieldLabel.label_text uid} set to #{d}"
        },
          :export_lambda => lambda {|obj|
            self.custom? ? obj.get_custom_value_by_id(@custom_id).value : obj.send("#{@field_name}")
          },
          :entity_type_field => false,
          :history_ignore => false
        }.merge(options)
    @uid = uid
    @core_module = core_module
    @sort_rank = rank
    @model = core_module.class_name.intern unless core_module.nil?
    @field_name = field
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
    @label_override = o[:label_override]
    @entity_type_field = o[:entity_type_field]
    @history_ignore = o[:history_ignore]
  end

  #returns the value of the process_export method based on the object found within the given piece set (or nil if the object is not found)
  def export_from_piece_set piece_set
    obj = self.core_module.object_from_piece_set piece_set
    obj.nil? ? nil : self.process_export(obj)
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

  #get the label that can be shown to the user.  If force_label is true or false, the CoreModule's prefix will or will not be appended.  If nil, it will use the default of the CoreModule's show_field_prefix
  def label(force_label=nil)
    do_prefix = force_label.nil? && self.core_module ? self.core_module.show_field_prefix : force_label
    r = do_prefix ? "#{self.core_module.label} - " : ""
    return "#{r}#{@label_override}" unless @label_override.nil?
    "#{r}#{FieldLabel.label_text @uid}"
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
      col = Kernel.const_get(@model).columns_hash[@field_name.to_s]
      return col.nil? ? nil : col.klass.to_s.downcase.to_sym #if col is nil, we probably haven't run the migration yet and are in the install process
    else
      return CustomDefinition.cached_find(@custom_id).data_type.downcase.to_sym
    end
  end
  
  #should be after all class level methods are declared
  MODEL_FIELDS = Hash.new
  def self.add_fields(core_module,descriptor_array)
    module_type = core_module.class_name.to_sym
    MODEL_FIELDS[module_type] = Hash.new if MODEL_FIELDS[module_type].nil?
    descriptor_array.each do |m|
      FieldLabel.set_default_value m[1], m[3]
      mf = ModelField.new(m[0],m[1],core_module,m[2],m[4].nil? ? {} : m[4])
      MODEL_FIELDS[module_type][mf.uid.to_sym] = mf
    end
  end 
  
  def self.make_division_arrays(rank_start,uid_prefix,table_name)
    r = [
      [rank_start,"#{uid_prefix}_div_id".to_sym,:division_id,"Division ID",{:history_ignore=>true}]
    ]
    n = [rank_start+1,"#{uid_prefix}_div_name".to_sym, :name,"Division Name",{
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
  def self.make_carrier_arrays(rank_start,uid_prefix,table_name)
    r = [
      [rank_start,"#{uid_prefix}_car_id".to_sym,:carrier_id,"Carrier ID",{:history_ignore=>true}]
    ]
    r << [rank_start+1,"#{uid_prefix}_car_name".to_sym, :name,"Carrier Name",{
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
    r << [rank_start+2,"#{uid_prefix}_car_syscode".to_sym,:system_code,"Carrier System Code", {
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
  def self.make_customer_arrays(rank_start,uid_prefix,table_name) 
    r = [
      [rank_start,"#{uid_prefix}_cust_id".to_sym,:customer_id,"Customer ID",{:history_ignore=>true}]
    ]
    r << [rank_start+1,"#{uid_prefix}_cust_name".to_sym, :name,"Customer Name", {
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
    r << [rank_start+2,"#{uid_prefix}_cust_syscode".to_sym,:system_code,"Customer System Code", {
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
  def self.make_vendor_arrays(rank_start,uid_prefix,table_name) 
    r = [
      [rank_start,"#{uid_prefix}_ven_id".to_sym,:vendor_id,"Vendor ID",{:history_ignore=>true}]
    ]
    r << [rank_start+1,"#{uid_prefix}_ven_name".to_sym, :name,"Vendor Name", {
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
    r << [rank_start+2,"#{uid_prefix}_ven_syscode".to_sym,:system_code,"Vendor System Code", {
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
  def self.make_ship_arrays(rank_start,uid_prefix,table_name,ft)
    raise "Invalid shipping from/to indicator provided: #{ft}" unless ["from","to"].include?(ft)
    ftc = ft.titleize
    r = [
      [rank_start,"#{uid_prefix}_ship_#{ft}_id".to_sym,"ship_#{ft}_id".to_sym,"Ship #{ftc} ID",{:history_ignore=>true}]
    ]
    n = [rank_start+1,"#{uid_prefix}_ship_#{ft}_name".to_sym,:name,"Ship #{ftc} Name", {
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

  def self.make_hts_arrays(rank_start,uid_prefix) 
    canada = Country.where(:iso_code=>"CA").first
    us = Country.where(:iso_code=>"US").first
    id_counter = rank_start
    r = []
    (1..3).each do |i|
      r << [id_counter,"#{uid_prefix}_hts_#{i}".to_sym, "hts_#{i}".to_sym,"HTS Code #{i}"]
      id_counter += 1
      r << [id_counter,"#{uid_prefix}_hts_#{i}_schedb".to_sym,"schedule_b_#{i}".to_sym,"Schedule B Code #{i}"] if us && us.import_location #make sure us exists so test fixtures pass
      id_counter += 1
      r << [id_counter,"#{uid_prefix}_hts_#{i}_gr".to_sym, :general_rate,"#{i} - General Rate",{
        :import_lambda => lambda {|obj,data| return "General Duty Rate cannot be set by import, ignored."},
        :export_lambda => lambda {|t|
          ot = case i
            when 1 then t.hts_1_official_tariff
            when 2 then t.hts_2_official_tariff
            when 3 then t.hts_3_official_tariff
          end
          ot.nil? ? "" : ot.general_rate 
        },
        :join_statement => "LEFT OUTER JOIN official_tariffs AS OT_#{i} on OT_#{i}.hts_code = tariff_records.hts_#{i} AND OT_#{i}.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1)",
        :join_alias => "OT_#{i}",
        :data_type=>:string,
        :history_ignore=>true
      }]
      id_counter += 1
      r << [id_counter,"#{uid_prefix}_hts_#{i}_cr".to_sym, :common_rate,"#{i} - Common Rate",{
        :import_lambda => lambda {|obj,data| return "Common Duty Rate cannot be set by import, ignored."},
        :export_lambda => lambda {|t|
          ot = case i
            when 1 then t.hts_1_official_tariff
            when 2 then t.hts_2_official_tariff
            when 3 then t.hts_3_official_tariff
          end
          ot.nil? ? "" : ot.common_rate 
        },
        :join_statement => "LEFT OUTER JOIN official_tariffs AS OT_#{i} on OT_#{i}.hts_code = tariff_records.hts_#{i} AND OT_#{i}.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1)",
        :join_alias => "OT_#{i}",
        :data_type=>:string,
        :history_ignore=>true
      }]
      if canada && canada.import_location
        id_counter += 1
        r << [id_counter,"#{uid_prefix}_hts_#{i}_gpt".to_sym, :general_preferential_tariff_rate,"#{i} - GPT Rate",{
          :import_lambda => lambda {|obj,data| return "GPT Rate cannot be set by import, ignored."},
          :export_lambda => lambda {|t|
            ot = case i
              when 1 then t.hts_1_official_tariff
              when 2 then t.hts_2_official_tariff
              when 3 then t.hts_3_official_tariff
            end
            ot.nil? ? "" : ot.general_preferential_tariff_rate
          },
          :join_statement => "LEFT OUTER JOIN official_tariffs AS OT_#{i} on OT_#{i}.hts_code = tariff_records.hts_#{i} AND OT_#{i}.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1)",
          :join_alias => "OT_#{i}",
          :data_type=>:string,
          :history_ignore=>true
        }]
      end
      if OfficialTariff.where("import_regulations is not null OR export_regulations is not null").count>0
        id_counter += 1
        r << [id_counter,"#{uid_prefix}_hts_#{i}_impregs".to_sym, :import_regulations,"#{i} - Import Regulations",{
          :import_lambda => lambda {|obj,data| return "HTS Import Regulations cannot be set by import, ignored."},
          :export_lambda => lambda {|t|
            ot = case i
              when 1 then t.hts_1_official_tariff
              when 2 then t.hts_2_official_tariff
              when 3 then t.hts_3_official_tariff
            end
            ot.nil? ? "" : ot.import_regulations
          },
          :join_statement => "LEFT OUTER JOIN official_tariffs AS OT_#{i} on OT_#{i}.hts_code = tariff_records.hts_#{i} AND OT_#{i}.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1)",
          :join_alias => "OT_#{i}",
          :data_type=>:string,
          :history_ignore=>true
        }]
        id_counter += 1
        r << [id_counter,"#{uid_prefix}_hts_#{i}_expregs".to_sym, :export_regulations,"#{i} - Export Regulations",{
          :import_lambda => lambda {|obj,data| return "HTS Export Regulations cannot be set by export, ignored."},
          :export_lambda => lambda {|t|
            ot = case i
              when 1 then t.hts_1_official_tariff
              when 2 then t.hts_2_official_tariff
              when 3 then t.hts_3_official_tariff
            end
            ot.nil? ? "" : ot.export_regulations
          },
          :join_statement => "LEFT OUTER JOIN official_tariffs AS OT_#{i} on OT_#{i}.hts_code = tariff_records.hts_#{i} AND OT_#{i}.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1)",
          :join_alias => "OT_#{i}",
          :data_type=>:string,
          :history_ignore=>true
        }]
      end
      id_counter += 1
      r << [id_counter,"#{uid_prefix}_hts_#{i}_qc".to_sym,:category,"#{i} - Quota Category",{
        :import_lambda => lambda {|obj,data| return "Quota Category cannot be set by import, ignored."},
        :export_lambda => lambda {|t|
          ot = case i
            when 1 then t.hts_1_official_tariff
            when 2 then t.hts_2_official_tariff
            when 3 then t.hts_3_official_tariff
          end
          return "" if ot.nil?
          q = ot.official_quota
          q.nil? ? "" : q.category
        },
        :join_statement => "LEFT OUTER JOIN official_quotas AS OQ_#{i} on OQ_#{i}.hts_code = tariff_records.hts_#{i} AND OQ_#{i}.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1)",
        :join_alias => "OQ_#{i}",
        :data_type=>:string,
        :history_ignore=>true
      }]
    end
    r
  end
  
  def self.make_ship_to_arrays(rank_start,uid_prefix,table_name)
    make_ship_arrays(rank_start,uid_prefix,table_name,"to")
  end
  def self.make_ship_from_arrays(rank_start,uid_prefix,table_name)
    make_ship_arrays(rank_start,uid_prefix,table_name,"from")
  end
  def self.make_country_arrays(rank_start,uid_prefix,table_name)
    r = []
    r << [rank_start,"#{uid_prefix}_cntry_name".to_sym, :name,"Country Name", {
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
    r << [rank_start+1,"#{uid_prefix}_cntry_iso".to_sym, :iso_code, "Country ISO Code",{
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
      :data_type=>:string,
      :history_ignore=>true
    }]
    r
  end
  def self.make_product_arrays(rank_start,uid_prefix,table_name)
    r = []
    r << [rank_start,"#{uid_prefix}_puid".to_sym, :unique_identifier,"Product Unique ID", {
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
    r << [rank_start+1,"#{uid_prefix}_pname".to_sym, :name,"Product Name",{
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
  def self.make_master_setup_array rank_start, uid_prefix
    r = []
    r << [rank_start,"#{uid_prefix}_system_code".to_sym,:system_code,"Master System Code", {
      :import_lambda => lambda {|detail,data| return "Master System Code cannot by set by import, ignored."},
      :export_lambda => lambda {|detail| return MasterSetup.get.system_code},
      :qualified_field_name => "ifnull(prod_class_count.class_count,0)",
      :data_type=>:string,
      :history_ignore=>true
    }]
  end
  def self.make_last_changed_by rank, uid_prefix, base_class
    table_name = base_class.table_name
    [rank,"#{uid_prefix}_last_changed_by".to_sym,:username,"Last Changed By", {
      :import_lambda => lambda {|a,b| return "Last Changed By cannot be set by import, ignored."},
      :export_lambda => lambda {|obj| 
        snap = obj.last_snapshot
        snap.blank? ? "" : snap.user.username
      },
      :join_statement =>"LEFT OUTER JOIN (SELECT recordable_id, id, user_id FROM entity_snapshots where id IN (SELECT MAX(id) FROM entity_snapshots WHERE entity_snapshots.recordable_type = '#{base_class}' GROUP BY recordable_type, recordable_id)) #{uid_prefix}_es on #{uid_prefix}_es.recordable_id = #{table_name}.id LEFT OUTER JOIN users #{uid_prefix}_es_u on #{uid_prefix}_es.user_id = #{uid_prefix}_es_u.id",
      :join_alias => "#{uid_prefix}_es_u",
      :qualified_field_name => "ifnull(#{uid_prefix}_es_u.username,'')",
      :data_type=>:string,
      :history_ignore => true
    }]
  end
  def self.make_broker_invoice_entry_field sequence_number, mf_uid,field_reference,label,data_type,ent_exp_lambda
      [sequence_number,mf_uid,field_reference,label,{:data_type=>data_type,
        :import_lambda => lambda {|inv,data| "#{label} cannot be set via invoice upload."},
        :export_lambda => lambda {|inv| inv.entry.blank? ? "" : ent_exp_lambda.call(inv.entry)},
        :join_statement => "LEFT OUTER JOIN entries as bi_entry ON bi_entry.id = broker_invoices.entry_id",
        :join_alias => "bi_entry"
      }]
  end

  def self.add_custom_fields(core_module,base_class,parameters={})
    max = 0
    m_type = core_module.class_name.intern
    model_hash = MODEL_FIELDS[m_type]
    model_hash.values.each {|mf| max = mf.sort_rank + 1 if mf.sort_rank > max}
    base_class.new.custom_definitions.each_with_index do |d,index|
      class_symbol = base_class.to_s.downcase
      fld = "*cf_#{d.id}".intern
      mf = ModelField.new(max+index,fld,core_module,fld,parameters.merge({:custom_id=>d.id,:label_override=>"#{d.label}"}))
      model_hash[mf.uid.to_sym] = mf
    end
  end
  
  def self.reset_custom_fields(update_cache_time=false)
    CoreModule::CORE_MODULES.each do |cm|
      h = MODEL_FIELDS[cm.class_name.to_sym]
      h.each do |k,v|
        h.delete k unless v.custom_id.nil?
      end
    end
    ModelField.add_custom_fields(CoreModule::ORDER,Order)
    ModelField.add_custom_fields(CoreModule::ORDER_LINE,OrderLine)
    ModelField.add_custom_fields(CoreModule::PRODUCT,Product)
    ModelField.add_custom_fields(CoreModule::CLASSIFICATION,Classification)
    ModelField.add_custom_fields(CoreModule::TARIFF,TariffRecord)
    ModelField.add_custom_fields(CoreModule::SHIPMENT,Shipment)
    ModelField.add_custom_fields(CoreModule::SHIPMENT_LINE,ShipmentLine)
    ModelField.add_custom_fields(CoreModule::SALE,SalesOrder)
    ModelField.add_custom_fields(CoreModule::SALE_LINE,SalesOrderLine)
    ModelField.add_custom_fields(CoreModule::DELIVERY,Delivery)
    ModelField.add_custom_fields(CoreModule::ENTRY,Entry)
    ModelField.add_custom_fields(CoreModule::BROKER_INVOICE,BrokerInvoice)
    ModelField.add_custom_fields(CoreModule::BROKER_INVOICE_LINE,BrokerInvoiceLine)
    @@last_loaded = Time.now
    Rails.logger.info "Setting CACHE ModelField:last_loaded to \'#{@@last_loaded}\'" if update_cache_time
    CACHE.set "ModelField:last_loaded", @@last_loaded if update_cache_time
  end

  def self.reload(update_cache_time=false)
    MODEL_FIELDS.clear
    add_fields CoreModule::OFFICIAL_TARIFF, [
      [1,:ot_hts_code,:hts_code,"HTS Code",{:data_type=>:string}],
      [2,:ot_full_desc,:full_description,"Full Description",{:data_type=>:string}],
      [3,:ot_spec_rates,:special_rates,"Special Rates",{:data_type=>:string}],
      [4,:ot_gen_rate,:general_rate,"General Rate",{:data_type=>:string}],
      [5,:ot_chapter,:chapter,"Chapter",{:data_type=>:string}],
      [6,:ot_heading,:heading,"Heading",{:data_type=>:string}],
      [7,:ot_sub_heading,:sub_heading,"Sub-Heading",{:data_type=>:string}],
      [8,:ot_remaining,:remaining_description,"Remaining Description",{:data_type=>:string}],
      [9,:ot_ad_v,:add_valorem_rate,"Ad Valorem Rate",{:data_type=>:string}],
      [10,:ot_per_u,:per_unit_rate,"Per Unit Rate",{:data_type=>:string}],
      [11,:ot_calc_meth,:calculation_method,"Calculation Method",{:data_type=>:string}],
      [12,:ot_mfn,:most_favored_nation_rate,"MFN Rate",{:data_type=>:string}],
      [13,:ot_gpt,:general_preferential_tariff_rate,"GPT Rate",{:data_type=>:string}],
      [14,:ot_erga_omnes_rate,:erga_omnes_rate,"Erga Omnes Rate",{:data_type=>:string}],
      [15,:ot_uom,:unit_of_measure,"Unit of Measure",{:data_type=>:string}],
      [16,:ot_col_2,:column_2_rate,"Column 2 Rate",{:data_type=>:string}],
      [17,:ot_import_regs,:import_regulations,"Import Regulations",{:data_type=>:string}],
      [18,:ot_export_regs,:export_regulations,"Export Regulations",{:data_type=>:string}],
      [19,:ot_common_rate,:common_rate,"Common Rate",{:data_type=>:string}]
    ]
    add_fields CoreModule::OFFICIAL_TARIFF, make_country_arrays(100,"ot","official_tariffs")
    add_fields CoreModule::ENTRY, [
      [1,:ent_brok_ref,:broker_reference, "Broker Reference",{:data_type=>:string}],
      [2,:ent_entry_num,:entry_number,"Entry Number",{:data_type=>:string}],
      [3,:ent_release_date,:release_date,"Release Date",{:data_type=>:datetime}],
      [4,:ent_comp_num,:company_number,"Broker Company Number",{:data_type=>:string}],
      [5,:ent_div_num,:division_number,"Broker Division Number",{:data_type=>:string}],
      [6,:ent_cust_num,:customer_number,"Customer Number",{:data_type=>:string}],
      [7,:ent_cust_name,:customer_name,"Customer Name",{:data_type=>:string}],
      [8,:ent_type,:entry_type,"Entry Type",{:data_type=>:string}],
      [9,:ent_arrival_date,:arrival_date,"Arrival Date",{:data_type=>:datetime}],
      [10,:ent_filed_date,:entry_filed_date,"Entry Filed Date",{:data_type=>:datetime}],
      [11,:ent_release_date,:release_date,"Release Date",{:data_type=>:datetime}],
      [12,:ent_first_release,:first_release_date,"First Release Date",{:data_type=>:datetime}],
      [13,:ent_free_date,:free_date,"Free Date",{:data_type=>:datetime}],
      [14,:ent_last_billed_date,:last_billed_date,"Last Bill Issued Date",{:data_type=>:datetime}],
      [15,:ent_invoice_paid_date,:invoice_paid_date,"Invoice Paid Date",{:data_type=>:datetime}],
      [16,:ent_liq_date,:liquidation_date,"Liquidation Date",{:data_type=>:datetime}],
      [17,:ent_mbols,:master_bills_of_lading,"Master Bills",{:data_type=>:text}],
      [18,:ent_hbols,:house_bills_of_lading,"House Bills",{:data_type=>:text}],
      [19,:ent_sbols,:sub_house_bills_of_lading,"Sub House Bills",{:data_type=>:text}],
      [20,:ent_it_numbers,:it_numbers,"IT Numbers",{:data_type=>:text}],
      [21,:ent_duty_due_date,:duty_due_date,"Duty Due Date",{:data_type=>:date}],
      [22,:ent_carrier_code,:carrier_code,"Carrier Code",{:data_type=>:string}],
      [23,:ent_total_packages,:total_packages,"Total Packages",{:data_type=>:integer}],
      [24,:ent_total_fees,:total_fees,"Total Fees",{:data_type=>:decimal}],
      [25,:ent_total_duty,:total_duty,"Total Duty",{:data_type=>:decimal}],
      [26,:ent_total_duty_direct,:total_duty_direct,"Total Duty Direct",{:data_type=>:decimal}],
      [27,:ent_entered_value,:entered_value,"Total Entered Value", {:data_type=>:decimal}],
      [28,:ent_customer_references,:customer_references,"Customer References",{:data_type=>:text}]
    ]
    add_fields CoreModule::BROKER_INVOICE, [
      make_broker_invoice_entry_field(1,:bi_brok_ref,:broker_reference,"Broker Reference",:string,lambda {|entry| entry.broker_reference}),
      [2,:bi_suffix,:suffix,"Suffix",:data_type=>:string],
      [3,:bi_invoice_date,:invoice_date,"Invoice Date",:data_type=>:date],
      [4,:bi_invoice_total,:invoice_total,"Total",:data_type=>:decimal],
      [5,:bi_customer_number,:customer_number,"Customer Number",:data_type=>:string],
      [6,:bi_to_name,:bill_to_name,"Bill To Name",:data_type=>:string],
      [7,:bi_to_add1,:bill_to_address_1,"Bill To Address 1",:data_type=>:string],
      [8,:bi_to_add2,:bill_to_address_2,"Bill To Address 2",:data_type=>:string],
      [9,:bi_to_city,:bill_to_city,"Bill To City",:data_type=>:string],
      [10,:bi_to_state,:bill_to_state,"Bill To State",:data_type=>:string],
      [11,:bi_to_zip,:bill_to_zip,"Bill To Zip",:data_type=>:string],
      make_broker_invoice_entry_field(12,:bi_entry_num,:entry_number,"Entry Number",:string,lambda {|entry| entry.entry_number}),
      make_broker_invoice_entry_field(13,:bi_release_date,:release_date,"Release Date",:string,lambda {|entry| entry.release_date}),
      make_broker_invoice_entry_field(13,:bi_release_date,:release_date,"Release Date",:string,lambda {|entry| entry.release_date}),
      [14,:bi_to_country_iso,:iso_code,"Bill To Country Code",{:data_type=>:string,
        :import_lambda=> lambda {|inv,data|
          ctry = Country.find_by_iso_code data
          "Country with ISO code #{data} could not be found." unless cntry
          inv.bill_to_country_id = cntry.id
          "Bill to Country set to #{data}"
        },
        :export_lambda=> lambda {|inv| inv.bill_to_country_id.blank? ? "" : inv.bill_to_country.iso_code},
        :join_statement => "LEFT OUTER JOIN countries as bi_country on bi_country.id = broker_invoices.bill_to_country_id"
      }],
      make_broker_invoice_entry_field(15,:bi_mbols,:master_bills_of_lading,"Master Bills",:text,lambda {|entry| entry.master_bills_of_lading}),
      make_broker_invoice_entry_field(16,:bi_hbols,:house_bills_of_lading,"House Bills",:text,lambda {|entry| entry.house_bills_of_lading}),
      make_broker_invoice_entry_field(17,:bi_sbols,:sub_house_bills_of_lading,"Sub House Bills",:text,lambda {|entry| entry.sub_house_bills_of_lading}),
      make_broker_invoice_entry_field(18,:bi_it_numbers,:it_numbers,"IT Numbers",:text,lambda {|entry| entry.it_numbers}),
      make_broker_invoice_entry_field(19,:bi_duty_due_date,:duty_due_date,"Duty Due Date",:date,lambda {|entry| entry.duty_due_date}),
      make_broker_invoice_entry_field(20,:bi_carrier_code,:carrier_code,"Carrier Code",:string,lambda {|entry| entry.carrier_code}),
      make_broker_invoice_entry_field(21,:bi_total_packages,:total_packages,"Total Packages",:integer,lambda {|entry| entry.total_packages}),
      make_broker_invoice_entry_field(22,:bi_total_fees,:total_fees,"Total Fees",:decimal,lambda {|entry| entry.total_fees}),
      make_broker_invoice_entry_field(25, :bi_ent_total_duty, :total_duty, "Total Duty", :decimal, lambda {|entry| entry.total_duty}),
      make_broker_invoice_entry_field(26, :bi_ent_total_duty_direct, :total_duty_direct, "Total Duty Direct", :decimal, lambda {|entry| entry.total_duty_direct}),
      make_broker_invoice_entry_field(27, :bi_ent_entered_value, :entered_value, "Total Entered Value", :decimal, lambda {|entry| entry.entered_value}),
      make_broker_invoice_entry_field(28, :bi_ent_customer_references, :customer_references, "Customer References", :text, lambda {|entry| entry.customer_references})
    ]
    add_fields CoreModule::BROKER_INVOICE_LINE, [
      [1,:bi_line_charge_code,:charge_code,"Charge Code",{:data_type=>:string}],
      [2,:bi_line_charge_description,:charge_description,"Description",{:data_type=>:string}],
      [3,:bi_line_charge_amount,:charge_amount,"Amount",{:data_type=>:decimal}],
      [4,:bi_line_vendor_name,:vendor_name,"Vendor",{:data_type=>:string}],
      [5,:bi_line_vendor_reference,:vendor_reference,"Vendor Reference",{:data_type=>:string}],
      [6,:bi_line_charge_type,:charge_type,"Charge Type",{:data_type=>:string}]
    ]
    add_fields CoreModule::PRODUCT, [
      [1,:prod_uid,:unique_identifier,"Unique Identifier",{:data_type=>:string}],
      [2,:prod_ent_type,:name,"Product Type",{:entity_type_field=>true,
        :import_lambda => lambda {|detail,data|
          et = EntityType.where(:name=>data).first
          if et
            detail.entity_type = et
            return "#{ModelField.find_by_uid(:prod_ent_type).label} set to #{et.name}."
          else
            return "#{ModelField.find_by_uid(:prod_ent_type).label} with name #{data} not found.  Field ignored."
          end
        },
        :export_lambda => lambda {|detail|
          et = detail.entity_type
          et.nil? ? "" : et.name
        },
        :join_statement => "LEFT OUTER JOIN entity_types AS prod_entity_type_name ON prod_entity_type_name.id = products.entity_type_id",
        :join_alias => "prod_entity_type_name",
        :data_type=>:integer
      }],
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
      }],
      [11,:prod_changed_at, :changed_at, "Last Changed",{:data_type=>:datetime}]
    ]
    add_fields CoreModule::PRODUCT, [make_last_changed_by(12,'prod',Product)]
    add_fields CoreModule::PRODUCT, make_vendor_arrays(5,"prod","products")
    add_fields CoreModule::PRODUCT, make_division_arrays(100,"prod","products")
    add_fields CoreModule::PRODUCT, make_master_setup_array(200,"prod")
    
    add_fields CoreModule::CLASSIFICATION, [
      [1,:class_comp_cnt, :comp_count, "Component Count", {
        :import_lambda => lambda {|obj,data| return "Component Count was ignored. (read only)"},
        :export_lambda => lambda {|obj| obj.tariff_records.size },
        :join_statement => "LEFT OUTER JOIN (SELECT count(id) as comp_count, classification_id FROM tariff_records group by classification_id) as class_comp_cnt ON class_comp_cnt.classification_id = classifications.id",
        :join_alias => "class_comp_cnt",
        :qualified_field_name => "ifnull(class_comp_cnt.comp_count,0)",
        :data_type => :integer
      }]
    ]
    add_fields CoreModule::CLASSIFICATION, make_country_arrays(100,"class","classifications")

    add_fields CoreModule::TARIFF, [
      [4,:hts_line_number,:line_number,"HTS Row"]
    ]
    add_fields CoreModule::TARIFF, make_hts_arrays(100,"hts")
    add_fields CoreModule::ORDER, [
      [1,:ord_ord_num,:order_number,"Order Number"],
      [2,:ord_ord_date,:order_date,"Order Date",{:data_type=>:date}],
      [3,:ord_ms_state,:state,"Milestone State",{:data_type=>:string,
        :import_lambda => lambda {|o,d| return "Milestone State was ignored. (read only)"},
        :export_lambda => lambda {|obj| obj.worst_milestone_state },
        :qualified_field_name => %{(SELECT milestone_forecast_sets.state as ms_state 
            FROM milestone_forecast_sets 
            INNER JOIN piece_sets on piece_sets.id = milestone_forecast_sets.piece_set_id 
            INNER JOIN order_lines on order_lines.id = piece_sets.order_line_id
            WHERE order_lines.order_id = orders.id 
            ORDER BY FIELD(milestone_forecast_sets.state,'Achieved','Pending','Unplanned','Missed','Trouble','Overdue') DESC LIMIT 1)}
      }]
    ]
    add_fields CoreModule::ORDER, make_vendor_arrays(100,"ord","orders")
    add_fields CoreModule::ORDER, make_ship_to_arrays(200,"ord","orders")
    add_fields CoreModule::ORDER, make_division_arrays(300,"ord","orders")
    add_fields CoreModule::ORDER, make_master_setup_array(400,"ord")

    add_fields CoreModule::ORDER_LINE, [
      [1,:ordln_line_number,:line_number,"Order - Row",{:data_type=>:integer}],
      [3,:ordln_ordered_qty,:quantity,"Order Quantity",{:data_type=>:decimal}],
      [4,:ordln_ppu,:price_per_unit,"Price / Unit",{:data_type=>:decimal}],
      [5,:ordln_ms_state,:state,"Milestone State",{:data_type=>:string,
        :import_lambda => lambda {|obj,data| return "Milestone State was ignored. (read only)"},
        :export_lambda => lambda {|obj| obj.worst_milestone_state },
        :qualified_field_name => "(SELECT IFNULL(milestone_forecast_sets.state,'') as ms_state FROM milestone_forecast_sets INNER JOIN piece_sets on piece_sets.id = milestone_forecast_sets.piece_set_id WHERE piece_sets.order_line_id = order_lines.id ORDER BY FIELD(milestone_forecast_sets.state,'Achieved','Pending','Unplanned','Missed','Trouble','Overdue') DESC LIMIT 1)"
      }]
    ]
    add_fields CoreModule::ORDER_LINE, make_product_arrays(100,"ordln","order_lines")

    add_fields CoreModule::SHIPMENT, [
      [1,:shp_ref,:reference,"Reference Number",{:data_type=>:string}],
      [2,:shp_mode,:mode,"Mode",{:data_type=>:string}],
    ]
    add_fields CoreModule::SHIPMENT, make_vendor_arrays(100,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_ship_to_arrays(200,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_ship_from_arrays(250,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_carrier_arrays(300,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_master_setup_array(400,"shp")
    
    add_fields CoreModule::SHIPMENT_LINE, [
      [1,:shpln_line_number,:line_number,"Shipment - Row",{:data_type=>:integer}],
      [2,:shpln_shipped_qty,:quantity,"Shipment Row Quantity",{:data_type=>:decimal}]
    ]
    add_fields CoreModule::SHIPMENT_LINE, make_product_arrays(100,"shpln","shipment_lines")


    add_fields CoreModule::SALE, [
      [1,:sale_order_number,:order_number,"Sale Number",{:data_type=>:string}],
      [2,:sale_order_date,:order_date,"Sale Date",{:data_type=>:date}],
    ]
    add_fields CoreModule::SALE, make_customer_arrays(100,"sale","sales_orders")
    add_fields CoreModule::SALE, make_ship_to_arrays(200,"sale","sales_orders")
    add_fields CoreModule::SALE, make_division_arrays(300,"sale","sales_orders")
    add_fields CoreModule::SALE, make_master_setup_array(400,"sale")

    add_fields CoreModule::SALE_LINE, [
      [1,:soln_line_number,:line_number,"Sale Row", {:data_type=>:integer}],
      [3,:soln_ordered_qty,:quantity,"Sale Quantity",{:data_type=>:decimal}],
      [4,:soln_ppu,:price_per_unit,"Price / Unit",{:data_type => :decimal}]
    ]
    add_fields CoreModule::SALE_LINE, make_product_arrays(100,"soln","sale_order_lines")
    
    add_fields CoreModule::DELIVERY, [
      [1,:del_ref,:reference,"Reference",{:data_type=>:string}],
      [2,:del_mode,:mode,"Mode",{:data_type=>:string}],
    ]
    add_fields CoreModule::DELIVERY, make_ship_from_arrays(100,"del","deliveries")
    add_fields CoreModule::DELIVERY, make_ship_to_arrays(200,"del","deliveries")
    add_fields CoreModule::DELIVERY, make_carrier_arrays(300,"del","deliveries")
    add_fields CoreModule::DELIVERY, make_customer_arrays(400,"del","deliveries")
    add_fields CoreModule::DELIVERY, make_master_setup_array(500,"del")

    add_fields CoreModule::DELIVERY_LINE, [
      [1,:delln_line_number,:line_number,"Delivery Row",{:data_type=>:integer}],
      [2,:delln_delivery_qty,:quantity,"Delivery Row Qauntity",{:data_type=>:decimal}]
    ]
    add_fields CoreModule::DELIVERY_LINE, make_product_arrays(100,"delln","delivery_lines")
    reset_custom_fields update_cache_time
  end

  reload 

  def self.find_by_uid(uid,dont_retry=false)
    return ModelField.new(10000,:_blank,nil,nil,{
      :label_override => "[blank]",
      :import_lambda => lambda {|o,d| "Field ignored"},
      :export_lambda => lambda {|o| },
      :data_type => :string
    }) if uid.to_sym == :_blank
    reload_if_stale
    MODEL_FIELDS.values.each do |h|
      u = uid.to_sym
      return h[u] unless h[u].nil?
    end
    unless dont_retry
      #reload and try again 
      ModelField.reload true 
      find_by_uid uid, true
    end
    return nil
  end
  
  def self.find_by_module_type(type_symbol)
    reload_if_stale
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

  def self.reload_if_stale
    cache_time = CACHE.get "ModelField:last_loaded"
    if !cache_time.nil? && !cache_time.is_a?(Time)
      begin
        raise "cache_time was a #{cache_time.class} object!"
      rescue
        $!.log_me ["cache_time: #{cache_time.to_s}","cache_time class: #{cache_time.class.to_s}","@@last_loaded: #{@@last_loaded}"]
      ensure
        cache_time = nil
        reload
      end
    end
    if !cache_time.nil? && (@@last_loaded.nil? || @@last_loaded < cache_time)
      reload
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
