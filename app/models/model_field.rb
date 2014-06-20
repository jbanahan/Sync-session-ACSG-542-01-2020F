require 'open_chain/field_logic'

class ModelField

  # When web mode is true, the class assumes that there is a before filter calling ModelField.reload_if_stale at the beginning of every request.
  # This means the class won't call memchached on every call to ModelField.find_by_uid to see if the ModelFieldSetups are stale
  # This should not be used outside of the web environment where jobs will be long running
  cattr_accessor :web_mode

  # if not empty, used by initializer to figure out the read_only? state
  @@field_validator_rules = HashWithIndifferentAccess.new
  @@public_field_cache = HashWithIndifferentAccess.new
  @@custom_definition_cache = HashWithIndifferentAccess.new

  @@last_loaded = nil
  attr_reader :model, :field_name, :label_prefix, :sort_rank, 
              :import_lambda, :export_lambda, 
              :custom_id, :data_type, :core_module, 
              :join_statement, :join_alias, :qualified_field_name, :uid, 
              :public, :public_searchable, :definition
  
  def initialize(rank,uid,core_module, field, options={})
    o = {:import_lambda =>  lambda {|obj,data|
          d = [:date,:datetime].include?(self.data_type) ? parse_date(data) : data
          if obj.is_a?(CustomValue)
            obj.value = d
          elsif self.custom?
            obj.get_custom_value(@custom_definition).value = d
          else
            obj.send("#{@field_name}=".intern,d)
          end
          return "#{FieldLabel.label_text uid} set to #{d}"
        },
          :export_lambda => lambda {|obj|
            self.custom? ? obj.get_custom_value(@custom_definition).value(@custom_definition) : obj.send("#{@field_name}")
          },
          :entity_type_field => false,
          :history_ignore => false,
          :read_only => false,
          :can_view_lambda => lambda {|u| true}
        }.merge(options)
    @uid = uid
    @core_module = core_module
    @sort_rank = rank
    @model = core_module.class_name.intern unless core_module.nil?
    @field_name = field
    @definition = o[:definition]
    @import_lambda = o[:import_lambda]
    @export_lambda = o[:export_lambda]
    @can_view_lambda = o[:can_view_lambda]
    @custom_id = o[:custom_id]
    @join_statement = o[:join_statement]
    @join_alias = o[:join_alias]
    @data_type = o[:data_type].nil? ? determine_data_type : o[:data_type]
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
    @custom_definition = nil
    if @custom_id
      if @@custom_definition_cache.empty?
        @custom_definition = CustomDefinition.find_by_id @custom_id
      else
        @custom_definition = @@custom_definition_cache[@uid]
      end
    end
    @process_query_result_lambda = o[:process_query_result_lambda]
    fvr = nil
    if @@field_validator_rules.empty?
      fvr = FieldValidatorRule.find_by_model_field_uid @uid
    else 
      fvr = @@field_validator_rules[@uid]
    end
    @read_only = o[:read_only] || (fvr && fvr.read_only?)
  end

  # do post processing on raw sql query result generated using qualified_field_name
  def process_query_result val, user
    return "HIDDEN" unless can_view? user
    result = @process_query_result_lambda ? @process_query_result_lambda.call(val) : val

    # Make sure all times returned from the database are translated to the user's timezone (or Eastern if user has no timezone)
    if result.respond_to?(:acts_like_time?) && result.acts_like_time?
      result = result.in_time_zone(ActiveSupport::TimeZone[user.try(:time_zone) ? user.time_zone : "Eastern Time (US & Canada)"])
    end

    result
  end

  # if true, then the field can't be updated with `process_import`
  def read_only?
    @read_only
  end
  # returns true if the given user should be allowed to view this field
  def can_view? user
    @can_view_lambda.call user 
  end

  # returns the default currency code for the value as a lowercase symbol (like :usd) or nil
  def currency
    @currency
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
    v = nil
    if self.read_only?
      v = "Value ignored. #{FieldLabel.label_text uid} is read only."
    else
      v = @import_lambda.call(obj,data)
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

  #show the value for the given field or "HIDDEN" if the user does not have field level permission
  #if always_view is true, then the user permission check will be skipped
  def process_export obj, user, always_view = false
    return "HIDDEN" unless always_view || can_view?(user)
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
  
  #Get the unique ID to be used for a given region and model field type
  def self.uid_for_region region, type
    "*r_#{region.id}_#{type}" 
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
      :qualified_field_name => "(SELECT name FROM divisions WHERE divisions.id = #{table_name}.division_id)",
      :join_statement => "LEFT OUTER JOIN divisions AS #{table_name}_div on #{table_name}_div.id = #{table_name}.division_id",
      :join_alias => "#{table_name}_div",
      :data_type => :string
    }]
    r << n
    r
  end
  def self.make_company_arrays(rank_start,uid_prefix,table_name,short_prefix,description,association_name)
    r = [
      [rank_start,"#{uid_prefix}_#{short_prefix}_id".to_sym,"#{association_name}_id".to_sym,"#{description} ID",{:history_ignore=>true}]
    ]
    r << [rank_start+1,"#{uid_prefix}_#{short_prefix}_name".to_sym, :name,"#{description} Name",{
      :import_lambda => lambda {|obj,data|
        if data.blank?
          obj.send("#{association_name}=".to_sym, nil)
          return "#{description} set to blank."
        else
          comp = Company.where(:name => data).where(association_name.to_sym => true).first
          unless comp.nil?
            obj.send("#{association_name}=".to_sym,comp)
            return "#{description} set to #{comp.name}"
          else
            comp = Company.create(:name=>data,association_name.to_sym=>true)
            obj.send("#{association_name}=".to_sym,comp)
            return "#{description} auto-created with name \"#{data}\""
          end
        end
      },
      :export_lambda => lambda {|obj| obj.send("#{association_name}".to_sym).nil? ? "" : obj.send("#{association_name}".to_sym).name},
      :qualified_field_name => "(SELECT name FROM companies WHERE companies.id = #{table_name}.#{association_name}_id)",
      :data_type => :string
    }]
    r << [rank_start+2,"#{uid_prefix}_#{short_prefix}_syscode".to_sym,:system_code,"#{description} System Code", {
      :import_lambda => lambda {|obj,data|
        if data.blank?
          obj.send("#{association_name}=".to_sym, nil)
          return "#{description} set to blank."
        else
          comp = Company.where(:system_code=>data,association_name.to_sym=>true).first
          unless comp.nil?
            obj.send("#{association_name}=".to_sym,comp)
            return "#{description} set to #{comp.name}"
          else
            return "#{description} not found with code \"#{data}\""
          end
        end
      },
      :export_lambda => lambda {|obj| obj.send("#{association_name}".to_sym).nil? ? "" : obj.send("#{association_name}".to_sym).system_code},
      :qualified_field_name => "(SELECT system_code FROM companies WHERE companies.id = #{table_name}.#{association_name}_id)",
      :data_type=>:string
    }]
    r
  end
  def self.make_carrier_arrays(rank_start,uid_prefix,table_name)
    make_company_arrays rank_start, uid_prefix, table_name, "car", "Carrier", "carrier"
  end
  def self.make_customer_arrays(rank_start,uid_prefix,table_name) 
    make_company_arrays rank_start, uid_prefix, table_name, "cust", "Customer", "customer"
  end
  def self.make_vendor_arrays(rank_start,uid_prefix,table_name) 
    make_company_arrays rank_start, uid_prefix, table_name, "ven", "Vendor", "vendor"
  end
  def self.make_importer_arrays(rank_start,uid_prefix,table_name)
    make_company_arrays rank_start, uid_prefix, table_name, "imp", "Importer", "importer"
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
      :qualified_field_name => "(SELECT name FROM addresses WHERE addresses.id = #{table_name}.ship_#{ft}_id)",
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
      r << [id_counter,"#{uid_prefix}_hts_#{i}".to_sym, "hts_#{i}".to_sym,"HTS Code #{i}",{
        :export_lambda => lambda {|t| 
          h = case i
            when 1 then t.hts_1
            when 2 then t.hts_2
            when 3 then t.hts_3
          end
          h.blank? ? "" : h.hts_format
        }, 
        :query_parameter_lambda => lambda {|t|
          case i
            when 1 then t.hts_1
            when 2 then t.hts_2
            when 3 then t.hts_3
          end
        },
        :process_query_result_lambda => lambda {|val|
          val.blank? ? "" : val.hts_format
        }
      }]
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
        :qualified_field_name => "(SELECT general_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.hts_code = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
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
        :qualified_field_name => "(SELECT common_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.hts_code = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
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
          :qualified_field_name => "(SELECT general_preferential_tariff_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.hts_code = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
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
          :qualified_field_name => "(SELECT import_regulations FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.hts_code = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
          :data_type=>:string,
          :history_ignore=>true
        }]
        id_counter += 1
        r << [id_counter,"#{uid_prefix}_hts_#{i}_expregs".to_sym, :export_regulations,"#{i} - Export Regulations",{
          :import_lambda => lambda {|obj,data| return "HTS Export Regulations cannot be set by import, ignored."},
          :export_lambda => lambda {|t|
            ot = case i
              when 1 then t.hts_1_official_tariff
              when 2 then t.hts_2_official_tariff
              when 3 then t.hts_3_official_tariff
            end
            ot.nil? ? "" : ot.export_regulations
          },
          :qualified_field_name => "(SELECT export_regulations FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.hts_code = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
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
        :qualified_field_name => "(SELECT category FROM official_quotas WHERE official_quotas.hts_code = tariff_records.hts_#{i} AND official_quotas.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
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
  def self.make_country_arrays(rank_start,uid_prefix,table_name,join='country')
    foreign_key = "#{join}_id"
    r = []
    r << [rank_start,"#{uid_prefix}_cntry_name".to_sym, :name,"Country Name", {
      :import_lambda => lambda {|detail,data|
        c = Country.where(:name => data).first
        eval "detail.#{join} = c"
        unless c.nil?
          return "Country set to #{c.name}"
        else
          return "Country not found with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| eval "detail.#{join}.nil? ? '' : detail.#{join}.name"},
      :qualified_field_name=>"(SELECT name from countries where countries.id = #{table_name}.#{foreign_key})",
      :data_type=>:string,
      :history_ignore=>true
    }]
    r << [rank_start+1,"#{uid_prefix}_cntry_iso".to_sym, :iso_code, "Country ISO Code",{
      :import_lambda => lambda {|detail,data|
        c = Country.where(:iso_code => data).first
        eval "detail.#{join} = c"
        unless c.nil?
          return "Country set to #{c.name}"
        else
          return "Country not found with ISO Code \"#{data}\""
        end    
      },
      :export_lambda => lambda {|detail| eval "detail.#{join}.nil? ? '' : detail.#{join}.iso_code"},
      :qualified_field_name=>"(SELECT iso_code from countries where countries.id = #{table_name}.#{foreign_key})",
      :data_type=>:string
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
      :qualified_field_name => "(SELECT unique_identifier FROM products WHERE products.id = #{table_name}.product_id)"
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
      :qualified_field_name => "(SELECT name FROM products WHERE products.id = #{table_name}.product_id)"
    }]
    r
  end
  def self.make_master_setup_array rank_start, uid_prefix
    r = []
    r << [rank_start,"#{uid_prefix}_system_code".to_sym,:system_code,"Master System Code", {
      :import_lambda => lambda {|detail,data| return "Master System Code cannot by set by import, ignored."},
      :export_lambda => lambda {|detail| return MasterSetup.get.system_code},
      :qualified_field_name => "(SELECT system_code FROM master_setups LIMIT 1)",
      :data_type=>:string,
      :history_ignore=>true
    }]
  end
  def self.make_last_changed_by rank, uid_prefix, base_class
    table_name = base_class.table_name
    [rank,"#{uid_prefix}_last_changed_by".to_sym,:username,"Last Changed By", {
      :import_lambda => lambda {|a,b| return "Last Changed By cannot be set by import, ignored."},
      :export_lambda => lambda {|obj| 
        obj.last_updated_by.blank? ? "" : obj.last_updated_by.username
      },
      :qualified_field_name => "(SELECT username FROM users where users.id = #{table_name}.last_updated_by_id)",
      :data_type=>:string,
      :history_ignore => true
    }]
  end
  def self.make_broker_invoice_entry_field sequence_number, mf_uid,field_reference,label,data_type,ent_exp_lambda,can_view_lambda=nil
    h = {:data_type=>data_type,
        :import_lambda => lambda {|inv,data| "#{label} cannot be set via invoice upload."},
        :export_lambda => lambda {|inv| inv.entry.blank? ? "" : ent_exp_lambda.call(inv.entry)},
        :qualified_field_name => "(SELECT #{field_reference} FROM entries where entries.id = broker_invoices.entry_id)"
      }
    h[:can_view_lambda]=can_view_lambda unless can_view_lambda.nil?
    [sequence_number,mf_uid,field_reference,label,h]
  end
  def self.make_sync_record_arrays sequence_start, prefix, table, class_name
    [
      [sequence_start,"#{prefix}_sync_record_count".to_sym, :sync_record_count, "Sync Record Count", {:data_type=>:integer,
        :import_lambda=> lambda {|o,d| "Number of Sync Records ignored. (read only)"},
        :export_lambda=> lambda {|obj| obj.sync_records.size},
        :qualified_field_name=> "(SELECT COUNT(*) FROM sync_records num_sr WHERE num_sr.syncable_id = #{table}.id AND num_sr.syncable_type = '#{class_name}')"
      }],
      [sequence_start+1,"#{prefix}_sync_problems".to_sym, :sync_problems, "Sync Record Problems?", {:data_type=>:boolean,
        :import_lambda=> lambda {|o,d| "Sync Record Problems ignored. (read only)"},
        :export_lambda=> lambda {|obj| obj.sync_records.problems.size > 0 ? true : false},
        :qualified_field_name=> "(SELECT CASE COUNT(*) WHEN 0 THEN false ELSE true END FROM sync_records sr_fail WHERE sr_fail.syncable_id = #{table}.id AND sr_fail.syncable_type = '#{class_name}' AND (#{SyncRecord.problems_clause('sr_fail.')}))"
      }],
      [sequence_start+2,"#{prefix}_sync_last_sent",:sync_last_sent,"Sync Record Last Sent",{
        data_type: :datetime,
        import_lambda: lambda {|o,d| "Sync Record Last Sent ignored (read only)"},
        export_lambda: lambda {|o| o.sync_records.collect {|r| r.sent_at}.compact.sort.last},
        qualified_field_name: "(SELECT max(sent_at) FROM sync_records where sync_records.syncable_id = #{table}.id AND sync_records.syncable_type = '#{class_name}')"
        }
      ],
      [sequence_start+3,"#{prefix}_sync_last_confirmed",:sync_last_confirmed,"Sync Record Last Confirmed",{
        data_type: :datetime,
        import_lambda: lambda {|o,d| "Sync Record Last Confirmed ignored (read only)"},
        export_lambda: lambda {|o| o.sync_records.collect {|r| r.confirmed_at}.compact.sort.last},
        qualified_field_name: "(SELECT max(confirmed_at) FROM sync_records where sync_records.syncable_id = #{table}.id AND sync_records.syncable_type = '#{class_name}')"
        }
      ]
    ]

  end

  def self.next_index_number(core_module)
    max = 0
    m_type = core_module.class_name.intern
    model_hash = MODEL_FIELDS[m_type]
    model_hash.values.each {|mf| max = mf.sort_rank + 1 if mf.sort_rank > max}
    max
  end

  def self.add_custom_fields(core_module,base_class,parameters={})
    m_type = core_module.class_name.intern
    model_hash = MODEL_FIELDS[m_type]
    max = next_index_number core_module
    base_class.new.custom_definitions.each_with_index do |d,index|
      class_symbol = base_class.to_s.downcase
      fld = "*cf_#{d.id}".intern
      mf = ModelField.new(max+index,fld,core_module,fld,parameters.merge({:custom_id=>d.id,:label_override=>"#{d.label}",
        :qualified_field_name=>"(SELECT IFNULL(#{d.data_column},\"\") FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{d.id})",
        :definition => d.definition
      }))
      model_hash[mf.uid.to_sym] = mf
    end
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
        h.delete k unless v.custom_id.nil?
      end
    end
    ModelField.add_custom_fields(CoreModule::ORDER,Order)
    ModelField.add_custom_fields(CoreModule::ORDER_LINE,OrderLine)
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
    ModelField.update_last_loaded update_cache_time
  end

  def self.add_country_hts_fields
    Country.import_locations.each do |c|
      (1..3).each do |i|
        mf = ModelField.new(next_index_number(CoreModule::PRODUCT),
          "*fhts_#{i}_#{c.id}".to_sym,
          CoreModule::PRODUCT,
          "*fhts_#{i}_#{c.id}".to_sym,
          {:label_override => "First HTS #{i} (#{c.iso_code})",
            :data_type=>:string,
            :history_ignore=>true,
            :import_lambda => lambda {|p,d|
              #validate HTS
              hts = TariffRecord.clean_hts(d)
              return "Blank HTS ignored for #{c.iso_code}" if hts.blank?
              unless OfficialTariff.find_by_country_id_and_hts_code(c.id,hts) || OfficialTariff.where(country_id:c.id).empty?
                e = "#{d} is not valid for #{c.iso_code} HTS #{i}"
                # Indicate the message is an error message
                def e.error?; true; end
                return e;
              end
              cls = nil
              #find classifications & tariff records in memory so this can work on objects that are dirty
              p.classifications.each do |existing| 
                cls = existing if existing.country_id == c.id
                break if cls
              end
              cls = p.classifications.build(:country_id=>c.id) unless cls
              tr = nil
              tr = cls.tariff_records.sort {|a,b| a.line_number <=> b.line_number}.first
              tr = cls.tariff_records.build unless tr
              tr.send("hts_#{i}=".intern,hts)
              "#{c.iso_code} HTS #{i} set to #{hts.hts_format}"
            },
            :export_lambda => lambda {|p|
              #do this in memory with a loop over classifications instead of a where
              #since there is a better probability that classifications will already be loaded
              #and we don't want to hit the database again
              cls = nil
              p.classifications.each do |cl|
                cls = cl if cl.country_id == c.id
                break if cls
              end
              return "" unless cls && cls.tariff_records.first
              h = cls.tariff_records.first.send "hts_#{i}"
              h.nil? ? "" : h.hts_format
            },
            :qualified_field_name => "(SELECT hts_#{i} FROM tariff_records INNER JOIN classifications ON tariff_records.classification_id = classifications.id WHERE classifications.country_id = #{c.id} AND classifications.product_id = products.id ORDER BY tariff_records.line_number LIMIT 1)",
            :process_query_result_lambda => lambda {|r| r.nil? ? nil : r.hts_format }
          }
        )
        MODEL_FIELDS[CoreModule::PRODUCT.class_name.intern][mf.uid.to_sym] = mf
      end
    end
  end

  def self.add_region_fields
    Region.all.each do |r|
      mf = ModelField.new(next_index_number(CoreModule::PRODUCT),
        "*r_#{r.id}_class_count".to_sym,
        CoreModule::PRODUCT,
        "*r_#{r.id}_class_count".to_sym, {
          :label_override => "Classification Count - #{r.name}",
          :import_lambda => lambda {|p,d| "Classification count ignored."},
          :export_lambda => lambda {|p|
            good_country_ids = Region.find(r.id).countries.collect {|c| c.id}
            cnt = 0
            p.classifications.each do |cl|
              cnt += 1 if good_country_ids.include?(cl.country_id) && cl.classified?
            end
            cnt
          },
          :data_type => :integer,
          :history_ignore => true,
          :qualified_field_name => "(
select count(*) from classifications 
inner join countries_regions on countries_regions.region_id = #{r.id} and countries_regions.country_id = classifications.country_id 
where (select count(*) from tariff_records where tariff_records.classification_id = classifications.id and length(tariff_records.hts_1)>0) > 0
and classifications.product_id = products.id
)"          
        }
      )
      MODEL_FIELDS[CoreModule::PRODUCT.class_name.intern][mf.uid.to_sym] = mf
    end
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

  def self.warm_expiring_caches
    public_field_cache do
      field_validator_rules_cache do
        custom_definition_cache do
          return yield
        end
      end
    end
  end

  def self.reload(update_cache_time=false)
    warm_expiring_caches do
      MODEL_FIELDS.clear
      add_fields CoreModule::SECURITY_FILING_LINE, [
        [2,:sfln_line_number,:line_number,"Line Number",{:data_type=>:integer}],
        [4,:sfln_hts_code,:hts_code,"HTS Code",{:data_type=>:string}],
        [5,:sfln_part_number,:part_number,"Part Number",{:data_type=>:string}],
        [6,:sfln_po_number,:po_number,"PO Number",{:data_type=>:string}],
        [7,:sfln_commercial_invoice_number,:commercial_invoice_number,"Commercial Invoice Number",{:data_type=>:string}],
        [8,:sfln_mid,:mid,"MID",{:data_type=>:string}],
        [9,:sfln_country_of_origin_code,:country_of_origin_code,"Country of Origin Code",{:data_type=>:string}],
        [10,:sfln_manufacturer_name,:manufacturer_name,"Manfacturer Name",{:data_type=>:string}]
      ]
      add_fields CoreModule::SECURITY_FILING, [
        [1,:sf_transaction_number,:transaction_number, "Transaction Number",{:data_type=> :string}],
        [2,:sf_host_system_file_number,:host_system_file_number, "Host System File Number",{:data_type=> :string}],
        [3,:sf_host_system,:host_system, "Host System",{:data_type=> :string,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [4,:sf_broker_customer_number,:broker_customer_number, "Customer Number",{:data_type=> :string}],
        [5,:sf_importer_tax_id,:importer_tax_id, "Importer Tax ID",{:data_type=> :string}],
        [6,:sf_transport_mode_code,:transport_mode_code, "Mode of Transport",{:data_type=> :string}],
        [7,:sf_scac,:scac, "SCAC Code",{:data_type=> :string}],
        [8,:sf_booking_number,:booking_number, "Booking Number",{:data_type=> :string}],
        [9,:sf_vessel,:vessel, "Vessel",{:data_type=> :string}],
        [10,:sf_voyage,:voyage, "Voyage",{:data_type=> :string}],
        [11,:sf_lading_port_code,:lading_port_code, "Port of Lading Code",{:data_type=> :string}],
        [12,:sf_unlading_port_code,:unlading_port_code, "Port of Unlading Code",{:data_type=> :string}],
        [13,:sf_entry_port_code,:entry_port_code, "Port of Entry Code",{:data_type=> :string}],
        [14,:sf_status_code,:status_code, "Customs Status Code",{:data_type=> :string}],
        [15,:sf_late_filing,:late_filing, "Late Filing",{:data_type=> :boolean,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [16,:sf_master_bill_of_lading,:master_bill_of_lading, "Master Bill of Lading",{:data_type=> :string}],
        [17,:sf_house_bills_of_lading,:house_bills_of_lading, "House Bill(s) of Lading",{:data_type=> :string}],
        [18,:sf_container_numbers,:container_numbers, "Container Numbers",{:data_type=> :string}],
        [19,:sf_entry_numbers,:entry_numbers, "Entry Number(s)",{:data_type=> :string}],
        [20,:sf_entry_reference_numbers,:entry_reference_numbers, "Entry File Number(s)",{:data_type=> :string}],
        [21,:sf_file_logged_date,:file_logged_date, "File Logged Date",{:data_type=> :datetime}],
        [22,:sf_first_sent_date,:first_sent_date, "First Sent Date",{:data_type=> :datetime}],
        [23,:sf_first_accepted_date,:first_accepted_date, "First Accepted Date",{:data_type=> :datetime}],
        [24,:sf_last_sent_date,:last_sent_date, "Last Sent Date",{:data_type=> :datetime}],
        [25,:sf_last_accepted_date,:last_accepted_date, "Last Accepted Date",{:data_type=> :datetime}],
        [26,:sf_estimated_vessel_load_date,:estimated_vessel_load_date, "Estimated Vessel Load Date",{:data_type=> :date}],
        [27,:sf_po_numbers,:po_numbers, "PO Number(s)",{:data_type=> :string}],
        [28,:sf_estimated_vessel_arrival_date,:estimated_vessel_arrival_date, "Estimated Vessel Arrival Date",{:data_type=> :date}],
        [29,:sf_countries_of_origin,:countries_of_origin,"Countries of Origin",{data_type: :text}],
        [30,:sf_estimated_vessel_sailing_date,:estimated_vessel_sailing_date, "Estimated Vessel Sailing Date",{:data_type=> :date}],
        [31,:sf_cbp_updated_at,:cbp_updated_at, "Last CBP Message Date",{:data_type => :datetime}],
        [32,:sf_status_description,:status_description, "Status Description", {:data_type => :string}],
        [33,:sf_last_event, :last_event, "Last Event Date", {:data_type => :datetime}],
        [34,:sf_manufacturer_names, :manufacturer_names, "Manufacturer Names", {:data_type => :text}]
      ]
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
        [19,:ot_common_rate,:common_rate,"Common Rate",{:data_type=>:string}],
        [20,:ot_chapter_number, :chapter_number,"Chapter Number",{:data_type=>:string,
            :import_lambda => lambda { |ent, data| 
              "Chapter Number ignored. (read only)"
            },
            :export_lambda => lambda { |obj|
              obj.hts_code[0,2]
            },
            :qualified_field_name => "LEFT(hts_code,2)"
          }
        ]
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
        [14,:ent_last_billed_date,:last_billed_date,"Last Bill Issued Date",{:data_type=>:datetime}],
        [15,:ent_invoice_paid_date,:invoice_paid_date,"Invoice Paid Date",{:data_type=>:datetime}],
        [16,:ent_liq_date,:liquidation_date,"Liquidation Date",{:data_type=>:datetime}],
        [17,:ent_mbols,:master_bills_of_lading,"Master Bills",{:data_type=>:text}],
        [18,:ent_hbols,:house_bills_of_lading,"House Bills",{:data_type=>:text}],
        [19,:ent_sbols,:sub_house_bills_of_lading,"Sub House Bills",{:data_type=>:text}],
        [20,:ent_it_numbers,:it_numbers,"IT Numbers",{:data_type=>:text}],
        [21,:ent_duty_due_date,:duty_due_date,"Duty Due Date",{:data_type=>:date,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [22,:ent_carrier_code,:carrier_code,"Carrier Code",{:data_type=>:string}],
        [23,:ent_total_packages,:total_packages,"Total Packages",{:data_type=>:integer}],
        [24,:ent_total_fees,:total_fees,"Total Fees",{:data_type=>:decimal,:currency=>:usd}],
        [25,:ent_total_duty,:total_duty,"Total Duty",{:data_type=>:decimal,:currency=>:usd}],
        [26,:ent_total_duty_direct,:total_duty_direct,"Total Duty Direct",{:data_type=>:decimal,:currency=>:usd}],
        [27,:ent_entered_value,:entered_value,"Total Entered Value", {:data_type=>:decimal,:currency=>:usd}],
        [28,:ent_customer_references,:customer_references,"Customer References",{:data_type=>:text}],
        [29,:ent_po_numbers,:po_numbers,"PO Numbers",{:data_type=>:text}],
        [30,:ent_mfids,:mfids,"MID Numbers",{:data_type=>:text}],
        [31,:ent_total_invoiced_value,:total_invoiced_value,"Total Commercial Invoice Value",{:data_type=>:decimal,:currency=>:usd}],
        [32,:ent_export_country_codes,:export_country_codes,"Country Export Codes",{:data_type=>:string}],
        [33,:ent_origin_country_codes,:origin_country_codes,"Country Origin Codes",{:data_type=>:string}],
        [34,:ent_vendor_names,:vendor_names,"Vendor Names",{:data_type=>:text}],
        [35,:ent_spis,:special_program_indicators,"SPI(s)",{:data_type=>:string}],
        [36,:ent_export_date,:export_date,"Export Date",{:data_type=>:date}],
        [37,:ent_merch_desc,:merchandise_description,"Merchandise Description",{:data_type=>:string}],
        [38,:ent_transport_mode_code,:transport_mode_code,"Mode of Transport",{:data_type=>:string}],
        [39,:ent_total_units,:total_units,"Total Units",{:data_type=>:decimal}],
        [40,:ent_total_units_uoms,:total_units_uoms,"Total Units UOMs",{:data_type=>:string}],
        [41,:ent_entry_port_code,:entry_port_code,"Port of Entry Code",{:data_type=>:string}],
        [42,:ent_ult_con_code,:ult_consignee_code,"Ult Consignee Code",{:data_type=>:string}],
        [43,:ent_ult_con_name,:ult_consignee_name,"Ult Consignee Name",{:data_type=>:string}],
        [44,:ent_gross_weight,:gross_weight,"Gross Weight",{:data_type=>:integer}],
        [45,:ent_total_packages_uom,:total_packages_uom,"Total Packages UOM",{:data_type=>:string}],
        [46,:ent_cotton_fee,:cotton_fee,"Cotton Fee",{:data_type=>:decimal,:currency=>:usd}],
        [47,:ent_hmf,:hmf,"HMF",{:data_type=>:decimal,:currency=>:usd}],
        [48,:ent_mpf,:mpf,"MPF",{:data_type=>:decimal,:currency=>:usd}],
        [49,:ent_container_nums,:container_numbers,"Container Numbers",{:data_type=>:string}],
        [50,:ent_container_sizes,:container_sizes,"Container Sizes",{:data_type=>:string}],
        [51,:ent_fcl_lcl,:fcl_lcl,"FCL/LCL",{:data_type=>:string}],
        [52,:ent_lading_port_code,:lading_port_code,"Port of Lading Code",{:data_type=>:string}],
        [53,:ent_unlading_port_code,:unlading_port_code,"Port of Unlading Code",{:data_type=>:string}],
        [54,:ent_consignee_address_1,:consignee_address_1,"Ult Consignee Address 1",{:data_type=>:string}],
        [55,:ent_consignee_address_2,:consignee_address_2,"Ult Consignee Address 2",{:data_type=>:string}],
        [56,:ent_consignee_city,:consignee_city,"Ult Consignee City",{:data_type=>:string}],
        [57,:ent_consignee_state,:consignee_state,"Ult Consignee State",{:data_type=>:string}],
        [58,:ent_lading_port_name,:name,"Port of Lading Name",{:data_type=>:string,
          :import_lambda => lambda { |ent, data|
            port = Port.find_by_name data
            return "Port with name \"#{data}\" could not be found." unless port
            ent.lading_port_code = port.schedule_k_code
            "Lading Port set to #{port.name}"
          },
          :export_lambda => lambda {|ent|
            ent.lading_port.blank? ? "" : ent.lading_port.name
          },
          :qualified_field_name => "(SELECT name FROM ports WHERE ports.schedule_k_code = entries.lading_port_code)"
        }],
        [59,:ent_unlading_port_name,:name,"Port of Unlading Name",{:data_type=>:string,
          :import_lambda => lambda { |ent, data|
            port = Port.find_by_name data
            return "Port with name \"#{data}\" could not be found." unless port
            ent.unlading_port_code = port.schedule_d_code
            "Unlading Port set to #{port.name}"
          },
          :export_lambda => lambda {|ent|
            ent.unlading_port.blank? ? "" : ent.unlading_port.name
          },
          :qualified_field_name => "(SELECT name FROM ports WHERE ports.schedule_d_code = entries.unlading_port_code)"
        }],
        [60,:ent_entry_port_name,:name,"Port of Entry Name",{:data_type=>:string,
          :import_lambda => lambda { |ent, data|
            port = Port.find_by_name data
            return "Port with name \"#{data}\" could not be found." unless port
            ent.entry_port_code = (ent.source_system == "Fenix" ? port.cbsa_port : port.schedule_d_code)
            "Entry Port set to #{port.name}"
          },
          :export_lambda => lambda {|ent|
            ent.entry_port.blank? ? "" : ent.entry_port.name
          },
          qualified_field_name: "(CASE entries.source_system WHEN 'Fenix' THEN (SELECT name FROM ports WHERE ports.cbsa_port = entries.entry_port_code) ELSE (SELECT name FROM ports WHERE ports.schedule_d_code = entries.entry_port_code) END)"
        }],
        [61,:ent_vessel,:vessel,"Vessel/Airline",{:data_type=>:string}],
        [62,:ent_voyage,:voyage,"Voyage/Flight",{:data_type=>:string}],
        [63,:ent_file_logged_date,:file_logged_date,"File Logged Date",{:data_type=>:datetime}],
        [64,:ent_last_exported_from_source,:last_exported_from_source,"System Extract Date",{:data_type=>:datetime}],
        [65,:ent_importer_tax_id,:importer_tax_id,"Importer Tax ID",{:data_type=>:string}],
        [66,:ent_cargo_control_number,:cargo_control_number,"Cargo Control Number",{:data_type=>:string}],
        [67,:ent_ship_terms,:ship_terms,"Ship Terms (CA)",{:data_type=>:string}],
        [68,:ent_direct_shipment_date,:direct_shipment_date,"Direct Shipment Date",{:data_type=>:date}],
        [69,:ent_across_sent_date,:across_sent_date,"ACROSS Sent Date",{:data_type=>:datetime}],
        [70,:ent_pars_ack_date,:pars_ack_date,"PARS ACK Date",{:data_type=>:datetime}],
        [71,:ent_pars_reject_date,:pars_reject_date,"PARS Reject Date",{:data_type=>:datetime}],
        [72,:ent_cadex_accept_date,:cadex_accept_date,"CADEX Accept Date",{:data_type=>:datetime}],
        [73,:ent_cadex_sent_date,:cadex_sent_date,"CADEX Sent Date",{:data_type=>:datetime}],
        [74,:ent_us_exit_port_code,:us_exit_port_code,"US Exit Port Code",{:data_type=>:string}],
        [75,:ent_origin_state_code,:origin_state_codes,"Origin State Codes",{:data_type=>:string}],
        [76,:ent_export_state_code,:export_state_codes,"Export State Codes",{:data_type=>:string}],
        [77,:ent_recon_flags,:recon_flags,"Recon Flags",{:data_type=>:string}],
        [78,:ent_ca_entry_type,:entry_type,"Entry Type (CA)",{:data_type=>:string}],
        [79, :ent_broker_invoice_total, :broker_invoice_total, "Total Broker Invoice", {:data_type=>:decimal, :currency=>:usd, :can_view_lambda=>lambda {|u| u.view_broker_invoices?}}],
        [80,:ent_release_cert_message,:release_cert_message, "Release Certification Message", {:data_type=>:string}],
        [81,:ent_fda_message,:fda_message,"FDA Message",{:data_type=>:string}],
        [82,:ent_fda_transmit_date,:fda_transmit_date,"FDA Transmit Date",{:data_type=>:datetime}],
        [83,:ent_fda_review_date,:fda_review_date,"FDA Review Date",{:data_type=>:datetime}],
        [84,:ent_fda_release_date,:fda_release_date,"FDA Release Date",{:data_type=>:datetime}],
        [85,:ent_charge_codes,:charge_codes,"Charge Codes Used",{:data_type=>:string, :can_view_lambda=>lambda {|u| u.view_broker_invoices?}}],
        [86,:ent_isf_sent_date,:isf_sent_date,"ISF Sent Date",{:data_type=>:datetime}],
        [87,:ent_isf_accepted_date,:isf_accepted_date,"ISF Accepted Date",{:data_type=>:datetime}],
        [88,:ent_docs_received_date,:docs_received_date,"Docs Received Date",{:data_type=>:date}],
        [89,:ent_trucker_called_date,:trucker_called_date,"Trucker Called Date",{:data_type=>:datetime}],
        [90,:ent_free_date,:free_date,"Free Date",{:data_type=>:date}],
        [91,:ent_edi_received_date,:edi_received_date,"EDI Received Date",{:data_type=>:date}],
        [92,:ent_ci_line_count,:ci_line_count, "Commercial Invoice Line Count",{
          :import_lambda=>lambda {|obj,data| "Commercial Invoice Line Count ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.commercial_invoice_lines.count},
          :qualified_field_name=>"(select count(*) from commercial_invoice_lines cil inner join commercial_invoices ci on ci.id = cil.commercial_invoice_id where ci.entry_id = entries.id)",
          :data_type=>:integer
          }
        ],
        [93,:ent_total_gst,:total_gst,"Total GST",{:data_type=>:decimal}],
        [94,:ent_total_duty_gst,:total_duty_gst,"Total Duty & GST",{:data_type=>:decimal}],
        [95,:ent_first_entry_sent_date,:first_entry_sent_date,"First Summary Sent Date",{:data_type=>:datetime,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [96,:ent_paperless_release,:paperless_release,"Paperless Entry Summary",{:data_type=>:boolean}],
        [97,:ent_census_warning,:census_warning,"Census Warning",{:data_type=>:boolean,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [98,:ent_error_free_release,:error_free_release,"Error Free Release",{:data_type=>:boolean,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [99,:ent_paperless_certification,:paperless_certification,"Paperless Release Cert",{:data_type=>:boolean}],
        [100,:ent_pdf_count,:pdf_count,"PDF Attachment Count", {
          :import_lambda=>lambda {|obj,data| "PDF Attachment Count ignored. (read only)"},
            :export_lambda=>lambda {|obj| obj.attachments.where("attached_content_type = 'application/pdf' OR lower(attached_file_name) LIKE '%pdf'").count},
          :qualified_field_name=>"(select count(*) from attachments where attachable_type = \"Entry\" and attachable_id = entries.id and (attached_content_type=\"application/pdf\"OR lower(attached_file_name) LIKE '%pdf'))",
          :data_type=>:integer,
          :can_view_lambda=> lambda {|u| u.company.broker?}
        }],
        [101,:ent_destination_state,:destination_state,"Destination State",{:data_type=>:string}],
        [102,:ent_liquidation_duty,:liquidation_duty,"Liquidated - Duty",{:data_type=>:decimal}],
        [103,:ent_liquidation_fees,:liquidation_fees,"Liquidated - Fees",{:data_type=>:decimal}],
        [104,:ent_liquidation_tax,:liquidation_tax,"Liquidated - Tax",{:data_type=>:decimal}],
        [105,:ent_liquidation_ada,:liquidation_ada,"Liquidated - ADA",{:data_type=>:decimal}],
        [106,:ent_liquidation_cvd,:liquidation_cvd,"Liquidated - CVD",{:data_type=>:decimal}],
        [107,:ent_liquidation_total,:liquidation_total,"Liquidated - Total",{:data_type=>:decimal}],
        [108,:ent_liquidation_extension_count,:liquidation_extension_count,"Liquidated - # of Extensions",{:data_type=>:integer}],
        [109,:ent_liquidation_extension_description,:liquidation_extension_description,"Liquidated - Extension",{:data_type=>:string}],
        [110,:ent_liquidation_extension_code,:liquidation_extension_code,"Liquidated - Extension Code",{:data_type=>:string}],
        [111,:ent_liquidation_action_description,:liquidation_action_description,"Liquidated - Action",{:data_type=>:string}],
        [112,:ent_liquidation_action_code,:liquidation_action_code,"Liquidated - Action Code",{:data_type=>:string}],
        [113,:ent_liquidation_type,:liquidation_type,"Liquidated - Type",{:data_type=>:string}],
        [114,:ent_liquidation_type_code,:liquidation_type_code,"Liquidated - Type Code",{:data_type=>:string}],
        [115,:ent_daily_statement_number,:daily_statement_number,"Daily Statement Number",{:data_type=>:string}],
        [116,:ent_daily_statement_due_date,:daily_statement_due_date,"Daily Statement Due",{:data_type=>:date}],
        [117,:ent_daily_statement_approved_date,:daily_statement_approved_date,"Daily Statement Approved Date",{:data_type=>:date}],
        [118,:ent_monthly_statement_number,:monthly_statement_number,"PMS #",{:data_type=>:string}],
        [119,:ent_monthly_statement_due_date,:monthly_statement_due_date,"PMS Due Date",{:data_type=>:date}],
        [120,:ent_monthly_statement_received_date,:monthly_statement_received_date,"PMS Received Date",{:data_type=>:date}],
        [121,:ent_monthly_statement_paid_date,:monthly_statement_paid_date,"PMS Paid Date",{:data_type=>:date}],
        [122,:ent_pay_type,:pay_type,"Pay Type",{:data_type=>:integer}],
        [123,:ent_statement_month,:statement_month,"PMS Month",{
          :import_lambda=>lambda {|obj,data| "PMS Month ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.monthly_statement_due_date ? obj.monthly_statement_due_date.month : nil},
          :qualified_field_name=>"month(monthly_statement_due_date)",
          :data_type=>:integer
        }],
        [124,:ent_first_7501_print,:first_7501_print,"7501 Print Date - First",{:data_type=>:datetime,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [125,:ent_last_7501_print,:last_7501_print,"7501 Print Date - Last",{:data_type=>:datetime,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [126,:ent_duty_billed,:duty_billed,"Total Duty Billed",{
          :import_lambda=>lambda {|obj,data| "Total Duty Billed ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.broker_invoice_lines.where(:charge_code=>'0001').sum(:charge_amount)},
          :qualified_field_name=>"(select sum(charge_amount) from broker_invoice_lines inner join broker_invoices on broker_invoices.id = broker_invoice_lines.broker_invoice_id where broker_invoices.entry_id = entries.id and charge_code = '0001')",
          :data_type=>:decimal,
          :can_view_lambda=>lambda {|u| u.view_broker_invoices? && u.company.broker?}
        }],
        [127,:ent_first_it_date,:first_it_date,"First IT Date",{:data_type=>:date}],
        [128,:ent_first_do_issued_date,:first_do_issued_date,"First DO Date",{:data_type=>:datetime}],
        [129,:ent_part_numbers,:part_numbers,"Part Numbers",{:data_type=>:text}],
        [130,:ent_commercial_invoice_numbers,:commercial_invoice_numbers,"Commercial Invoice Numbers",{:data_type=>:text}],
        [131,:ent_eta_date,:eta_date,"ETA Date",{:data_type=>:date}],
        [132,:ent_delivery_order_pickup_date,:delivery_order_pickup_date,"Delivery Order Pickup Date",{:data_type=>:datetime}],
        [133,:ent_freight_pickup_date,:freight_pickup_date,"Freight Pickup Date",{:data_type=>:datetime}],
        [134,:ent_k84_receive_date, :k84_receive_date, "K84 Received Date", {:data_type=>:date}],
        [135,:ent_k84_month, :k84_month, "K84 Month", {:data_type=>:integer}],
        [136,:ent_k84_due_date, :k84_due_date, "K84 Due Date", {:data_type=>:date}],
        [137,:ent_rule_state,:rule_state,"Business Rule State",{:data_type=>:string,
          :import_lambda=>lambda {|o,d| "Business Rule State ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.business_rules_state },
          :qualified_field_name=> "(select state 
            from business_validation_results bvr 
            where bvr.validatable_type = 'Entry' and bvr.validatable_id = entries.id 
            order by (
            case bvr.state
                when 'Fail' then 0
                when 'Review' then 1
                when 'Pass' then 2
                when 'Skipped' then 3
                else 4
            end
            )
            limit 1)",
          :can_view_lambda=>lambda {|u| u.company.master?}
        }],
        [138,:ent_carrier_name,:carrier_name,"Carrier Name", {:data_type=>:string}],
        [139,:ent_exam_ordered_date,:exam_ordered_date,"Exam Ordered Date",{:data_type=>:datetime}],
        [140,:ent_employee_name,:employee_name,"Employee",{:data_type=>:string,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [141,:ent_location_of_goods,:location_of_goods,"Location Of Goods", {:data_type=>:string}],
        [142,:ent_final_statement_date,:final_statement_date,"Final Statement Date", {:data_type=>:date}],
        [143,:ent_bond_type,:bond_type,"Bond Type", {:data_type=>:string}],
        [146,:ent_worksheeet_date,:worksheet_date,"Worksheet Date",{:data_type=>:date}],
        [147,:ent_available_date,:available_date,"Available Date",{:data_type=>:date}],
        [148,:ent_departments, :departments, "Departments", {:data_type=>:text}],
      ]
      add_fields CoreModule::ENTRY, make_country_arrays(500,'ent',"entries","import_country")
      add_fields CoreModule::ENTRY, make_sync_record_arrays(600,'ent','entries','Entry')
      add_fields CoreModule::COMMERCIAL_INVOICE, [
        [1,:ci_invoice_number,:invoice_number,"Invoice Number",{:data_type=>:string}],
        [2,:ci_vendor_name,:vendor_name,"Vendor Name",{:data_type=>:string}],
        [3,:ci_currency,:currency,"Currency",{:data_type=>:string}],
        [4,:ci_invoice_value_foreign,:invoice_value_foreign,"Invoice Value (Foreign)",{:data_type=>:decimal,:currency=>:other}],
        [5,:ci_invoice_value,:invoice_value,"Invoice Value",{:data_type=>:decimal,:currency=>:usd}],
        [6,:ci_country_origin_code,:country_origin_code,"Country Origin Code",{:data_type=>:string}],
        [7,:ci_gross_weight,:gross_weight,"Gross Weight",{:data_type=>:integer}],
        [8,:ci_total_charges,:total_charges,"Charges",{:data_type=>:decimal,:currency=>:usd}],
        [9,:ci_invoice_date,:invoice_date,"Invoice Date",{:data_type=>:date}],
        [10,:ci_mfid,:mfid,"MID",{:data_type=>:string}],
        [11,:ci_exchange_rate,:exchange_rate,"Exchange Rate",{:data_type=>:decimal}],
        [12,:ci_total_quantity, :total_quantity, "Quantity",{:data_type=>:decimal}],
        [13,:ci_total_quantity_uom, :total_quantity_uom, "Quantity UOM",{:data_type=>:string}],
        [14,:ci_docs_received_date,:docs_received_date,'Docs Received Date',{data_type: :date}],
        [15,:ci_docs_ok_date,:docs_ok_date,'Docs OK Date',{data_type: :date}],
        [16,:ci_issue_codes,:issue_codes,'Issue Tracking Codes',{data_type: :string}],
        [17,:ci_rater_comments,:rater_comments,'Rater Comments',{data_type: :text}],
        [18,:ci_destination_code,:destination_code,'Destination Code',{data_type: :string}]
      ]
      add_fields CoreModule::COMMERCIAL_INVOICE, make_importer_arrays(100,'ci','commercial_invoices')
      add_fields CoreModule::COMMERCIAL_INVOICE_LINE, [
        [1,:cil_line_number,:line_number,"Line Number",{:data_type=>:integer}],
        [2,:cil_part_number,:part_number,"Part Number",{:data_type=>:string}],
        [4,:cil_po_number,:po_number,"PO Number",{:data_type=>:string}],
        [7,:cil_units,:quantity,"Units",{:data_type=>:decimal}],
        [8,:cil_uom,:unit_of_measure,"UOM",{:data_type=>:string}],
        [9,:cil_value,:value,"Value",{:data_type=>:decimal,:currency=>:other}],
        [10,:cil_mid,:mid,"MID",{:data_type=>:string}],
        [11,:cil_country_origin_code,:country_origin_code,"Country Origin Code",{:data_type=>:string}],
        [12,:cil_country_export_code,:country_export_code,"Country Export Code",{:data_type=>:string}],
        [13,:cil_related_parties,:related_parties,"Related Parties",{:data_type=>:boolean}],
        [14,:cil_volume,:volume,"Volume",{:data_type=>:decimal}],
        #The next 3 lines have the wrong prefix because they were accidentally deployed to production this way and may be used on
        #reports.  It only hurts readability, so don't change them.
        [15,:ent_state_export_code,:state_export_code,"State Export Code",{:data_type=>:string}],
        [16,:ent_state_origin_code,:state_origin_code,"State Origin Code",{:data_type=>:string}],
        [17,:ent_unit_price,:unit_price,"Unit Price",{:data_type=>:decimal}],
        [18,:cil_department,:department,"Department",{:data_type=>:string}],
        [19,:cil_hmf,:hmf,"HMF",{:data_type=>:decimal}],
        [20,:cil_mpf,:mpf,"MPF - Full",{:data_type=>:decimal}],
        [21,:cil_prorated_mpf,:prorated_mpf,"MPF - Prorated",{:data_type=>:decimal}],
        [22,:cil_cotton_fee,:cotton_fee,"Cotton Fee",{:data_type=>:decimal}],
        [23,:cil_contract_amount,:contract_amount,"Contract Amount",{:data_type=>:decimal,:currency=>:other}],
        [24,:cil_add_case_number,:add_case_number,"ADD Case Number",{:data_type=>:string}],
        [25,:cil_add_bond,:add_bond,"ADD Bond",{:data_type=>:boolean}],
        [26,:cil_add_case_value,:add_case_value,"ADD Value",{:data_type=>:decimal,:currency=>:other}],
        [27,:cil_add_duty_amount,:add_duty_amount,"ADD Duty",{:data_type=>:decimal,:currency=>:other}],
        [28,:cil_add_case_percent,:add_case_percent,"ADD Percentage",{:data_type=>:decimal}],
        [29,:cil_cvd_case_number,:cvd_case_number,"CVD Case Number",{:data_type=>:string}],
        [30,:cil_cvd_bond,:cvd_bond,"CVD Bond",{:data_type=>:boolean}],
        [31,:cil_cvd_case_value,:cvd_case_value,"CVD Value",{:data_type=>:decimal,:currency=>:other}],
        [32,:cil_cvd_duty_amount,:cvd_duty_amount,"CVD Duty",{:data_type=>:decimal,:currency=>:other}],
        [33,:cil_cvd_case_percent,:cvd_case_percent,"CVD Percentage",{:data_type=>:decimal}],
        [34,:cil_customer_reference, :customer_reference, "Customer Reference",{:data_type=>:string}],
        [35,:cil_vendor_name, :vendor_name, "Vendor Name",{:data_type=>:string}],
        [36,:cil_adjustments_amount, :adjustments_amount, "Adjustments Amount",{:data_type=>:decimal,:currency=>:other}],
        [37,:cil_adjusted_value, :adjusted_value, "Adjusted Value",{:data_type=>:decimal,:currency=>:other,
          :import_lambda=>lambda {|o,d| "Adjusted Value ignored. (read only)"},
          :export_lambda=>lambda {|obj| (obj.adjustments_amount ? obj.adjustments_amount : BigDecimal.new(0)) + (obj.value ? obj.value : BigDecimal.new(0))},
          :qualified_field_name=> "(ifnull(commercial_invoice_lines.adjustments_amount,0) + ifnull(commercial_invoice_lines.value,0))",
        }],
        [38,:cil_total_duty, :total_duty, "Total Duty", {:data_type=>:decimal,:currency=>:other,
          :import_lambda=>lambda {|o,d| "Total Duty ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.total_duty },
          :qualified_field_name=> "(SELECT ifnull(sum(total_duty_t.duty_amount), 0) FROM commercial_invoice_tariffs total_duty_t 
            WHERE total_duty_t.commercial_invoice_line_id = commercial_invoice_lines.id)"
        }],
        [39,:cil_total_fees, :total_fees, "Total Fees", {:data_type=>:decimal,:currency=>:other,
          :import_lambda=>lambda {|o,d| "Total Fees ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.total_fees },
          :qualified_field_name=> "(SELECT ifnull(total_fees_l.prorated_mpf, 0) + ifnull(total_fees_l.hmf, 0) + ifnull(total_fees_l.cotton_fee, 0) FROM commercial_invoice_lines total_fees_l
            WHERE total_fees_l.id = commercial_invoice_lines.id)"
        }],
        [40,:cil_total_duty_plus_fees, :duty_plus_fees_amount, "Total Duty + Fees", {:data_type=>:decimal,:currency=>:other,
          :import_lambda=>lambda {|o,d| "Total Fees ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.duty_plus_fees_amount },
          :qualified_field_name=> "(SELECT ifnull(total_duty_fees_l.prorated_mpf, 0) + ifnull(total_duty_fees_l.hmf, 0) + ifnull(total_duty_fees_l.cotton_fee, 0) + 
              (SELECT ifnull(sum(total_duty_fees_t.duty_amount), 0) 
                FROM commercial_invoice_tariffs total_duty_fees_t 
                WHERE total_duty_fees_t.commercial_invoice_line_id = commercial_invoice_lines.id) 
            FROM commercial_invoice_lines total_duty_fees_l
            WHERE total_duty_fees_l.id = commercial_invoice_lines.id)"
        }],
        [41,:cil_customs_line_number, :customs_line_number, "Customs Line Number",{:data_type=>:integer}],
        [42,:cil_product_line, :product_line, "Product Line",{:data_type=>:string}],
        [43,:cil_visa_number, :visa_number, "Visa Number",{:data_type=>:string}],
        [44,:cil_visa_quantity, :visa_quantity, "Visa Quantity",{:data_type=>:decimal}],
        [45,:cil_visa_uom, :visa_uom, "Visa UOM",{:data_type=>:string}],
        [46,:cil_value_foreign,:value_foreign,'Value (Foreign)',{data_type: :decimal, currency: :other}],
        [47,:cil_currency,:currency,'Currency',{data_type: :string}]
      ]
      add_fields CoreModule::COMMERCIAL_INVOICE_TARIFF, [
        [1,:cit_hts_code,:hts_code,"HTS Code",{:data_type=>:string,:export_lambda=>lambda{|t| t.hts_code.blank? ? "" : t.hts_code.hts_format}}],
        [2,:cit_duty_amount,:duty_amount,"Duty",{:data_type=>:decimal}],
        [3,:cit_entered_value,:entered_value,"Entered Value",{:data_type=>:decimal}],
        [4,:cit_spi_primary,:spi_primary,"SPI - Primary",{:data_type=>:string}],
        [5,:cit_spi_secondary,:spi_secondary,"SPI - Secondary",{:data_type=>:string}],
        [6,:cit_classification_qty_1,:classification_qty_1,"Quanity 1",{:data_type=>:decimal}],
        [7,:cit_classification_uom_1,:classification_uom_1,"UOM 1",{:data_type=>:string}],
        [8,:cit_classification_qty_2,:classification_qty_2,"Quanity 2",{:data_type=>:decimal}],
        [9,:cit_classification_uom_2,:classification_uom_2,"UOM 2",{:data_type=>:string}],
        [10,:cit_classification_qty_3,:classification_qty_3,"Quanity 3",{:data_type=>:decimal}],
        [11,:cit_classification_uom_3,:classification_uom_3,"UOM 3",{:data_type=>:string}],
        [12,:cit_gross_weight,:gross_weight,"Gross Weight",{:data_type=>:integer}],
        [13,:cit_tariff_description,:tariff_description,"Description",{:data_type=>:string}],
        [18,:ent_tariff_provision,:tariff_provision,"Tariff Provision",{:data_type=>:string}],
        [19,:ent_value_for_duty_code,:value_for_duty_code,"VFD Code",{:data_type=>:string}],
        [20,:ent_gst_rate_code,:gst_rate_code,"GST Rate Code",{:data_type=>:string}],
        [21,:ent_gst_amount,:gst_amount,"GST Amount",{:data_type=>:decimal}],
        [22,:ent_sima_amount,:sima_amount,"SIMA Amount",{:data_type=>:decimal}],
        [23,:ent_excise_amount,:excise_amount,"Excise Amount",{:data_type=>:decimal}],
        [24,:ent_excise_rate_code,:excise_rate_code,"Excise Rate Code",{:data_type=>:string}],
        [25,:cit_duty_rate,:duty_rate,"Duty Rate",{:data_type=>:decimal}],
        [26,:cit_quota_category,:quota_category,"Quota Category",{:data_type=>:integer}]
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
        make_broker_invoice_entry_field(13,:bi_release_date,:release_date,"Release Date",:datetime,lambda {|entry| entry.release_date}),
        [14,:bi_to_country_iso,:iso_code,"Bill To Country Code",{:data_type=>:string,
          :import_lambda=> lambda {|inv,data|
            ctry = Country.find_by_iso_code data
            return "Country with ISO code #{data} could not be found." unless cntry
            inv.bill_to_country_id = cntry.id
            "Bill to Country set to #{data}"
          },
          :export_lambda=> lambda {|inv| inv.bill_to_country_id.blank? ? "" : inv.bill_to_country.iso_code},
          :qualified_field_name => "(SELECT iso_code FROM countries WHERE countries.id = broker_invoices.bill_to_country_id)"
        }],
        make_broker_invoice_entry_field(15,:bi_mbols,:master_bills_of_lading,"Master Bills",:text,lambda {|entry| entry.master_bills_of_lading}),
        make_broker_invoice_entry_field(16,:bi_hbols,:house_bills_of_lading,"House Bills",:text,lambda {|entry| entry.house_bills_of_lading}),
        make_broker_invoice_entry_field(17,:bi_sbols,:sub_house_bills_of_lading,"Sub House Bills",:text,lambda {|entry| entry.sub_house_bills_of_lading}),
        make_broker_invoice_entry_field(18,:bi_it_numbers,:it_numbers,"IT Numbers",:text,lambda {|entry| entry.it_numbers}),
        make_broker_invoice_entry_field(19,:bi_duty_due_date,:duty_due_date,"Duty Due Date",:date,lambda {|entry| entry.duty_due_date},lambda {|u| u.company.broker?}),
        make_broker_invoice_entry_field(20,:bi_carrier_code,:carrier_code,"Carrier Code",:string,lambda {|entry| entry.carrier_code}),
        make_broker_invoice_entry_field(21,:bi_total_packages,:total_packages,"Total Packages",:integer,lambda {|entry| entry.total_packages}),
        make_broker_invoice_entry_field(22,:bi_total_fees,:total_fees,"Total Fees",:decimal,lambda {|entry| entry.total_fees}),
        make_broker_invoice_entry_field(25, :bi_ent_total_duty, :total_duty, "Total Duty", :decimal, lambda {|entry| entry.total_duty}),
        make_broker_invoice_entry_field(26, :bi_ent_total_duty_direct, :total_duty_direct, "Total Duty Direct", :decimal, lambda {|entry| entry.total_duty_direct}),
        make_broker_invoice_entry_field(27, :bi_ent_entered_value, :entered_value, "Total Entered Value", :decimal, lambda {|entry| entry.entered_value}),
        make_broker_invoice_entry_field(28, :bi_ent_customer_references, :customer_references, "Customer References", :text, lambda {|entry| entry.customer_references}),
        make_broker_invoice_entry_field(29,:bi_ent_po_numbers,:po_numbers,"PO Numbers",:text,lambda {|entry| entry.po_numbers}),
        make_broker_invoice_entry_field(30,:bi_ent_mfids,:mfids,"MID Numbers",:text,lambda {|entry| entry.mfids}),
        make_broker_invoice_entry_field(31,:bi_ent_total_invoiced_value,:total_invoiced_value,"Total Commercial Invoice Value",:decimal,lambda {|entry| entry.total_invoiced_value}),
        make_broker_invoice_entry_field(32,:bi_ent_export_country_codes,:export_country_codes,"Country of Export Codes",:string,lambda {|entry| entry.export_country_codes}),
        make_broker_invoice_entry_field(33,:bi_ent_origin_country_codes,:origin_country_codes,"Country of Origin Codes",:string,lambda {|entry| entry.origin_country_codes}),
        make_broker_invoice_entry_field(34,:bi_ent_vendor_names,:vendor_names,"Vendor Names",:text,lambda {|entry| entry.vendor_names}),
        make_broker_invoice_entry_field(35,:bi_ent_spis,:special_program_indicators,"SPI(s),",:string,lambda {|entry| entry.special_program_indicators}),
        make_broker_invoice_entry_field(36,:bi_ent_export_date,:export_date,"Export Date",:date,lambda {|entry| entry.export_date}),
        make_broker_invoice_entry_field(37,:bi_ent_merch_desc,:merchandise_description,"Merchandise Description",:string,lambda {|entry| entry.merchandise_description}),
        make_broker_invoice_entry_field(38,:bi_ent_transport_mode_code,:transport_mode_code,"Mode of Transport",:string,lambda {|entry| entry.transport_mode_code}),
        make_broker_invoice_entry_field(39,:bi_ent_total_units,:total_units,"Total Units",:decimal,lambda {|entry| entry.total_units}),
        make_broker_invoice_entry_field(40,:bi_ent_total_units_uoms,:total_units_uoms,"Total Units UOMs",:string,lambda {|entry| entry.total_units_uoms}),
        make_broker_invoice_entry_field(41,:bi_ent_entry_port_code,:entry_port_code,"Port of Entry Code",:string,lambda {|entry| entry.entry_port_code}),
        make_broker_invoice_entry_field(42,:bi_ent_ult_con_code,:ult_consignee_code,"Ult Consignee Code",:string,lambda {|entry| entry.ult_consignee_code}),
        make_broker_invoice_entry_field(43,:bi_ent_ult_con_name,:ult_consignee_name,"Ult Consignee Name",:string,lambda {|entry| entry.ult_consignee_name}),
        make_broker_invoice_entry_field(44,:bi_ent_gross_weight,:gross_weight,"Gross Weight",:integer,lambda {|entry| entry.gross_weight}),
        make_broker_invoice_entry_field(45,:bi_ent_total_packages_uom,:total_packages_uom,"Total Packages UOM",:string,lambda {|entry| entry.total_packages_uom}),
        make_broker_invoice_entry_field(46,:bi_ent_cotton_fee,:cotton_fee,"Cotton Fee",:decimal,lambda {|entry| entry.cotton_fee}),
        make_broker_invoice_entry_field(47,:bi_ent_hmf,:hmf,"HMF",:decimal,lambda {|entry| entry.hmf}),
        make_broker_invoice_entry_field(48,:bi_ent_mpf,:mpf,"MPF",:decimal,lambda {|entry| entry.mpf}),
        make_broker_invoice_entry_field(49,:bi_ent_container_numbers,:container_numbers,"Container Numbers",:text,lambda {|entry| entry.container_numbers}),
        [50,:bi_currency,:currency,"Currency",{:data_type=>:decimal}],
        make_broker_invoice_entry_field(51,:bi_ent_importer_tax_id,:importer_tax_id,"Importer Tax ID",:string,lambda {|entry| entry.importer_tax_id}),
        make_broker_invoice_entry_field(52,:bi_destination_state,:destination_state,"Destination State",:string,lambda {|entry| entry.destination_state}),
        make_broker_invoice_entry_field(53,:bi_container_sizes,:container_sizes,"Container Sizes",:string,lambda {|entry| entry.container_sizes}),
        [54,:bi_lading_port_name,:name,"Port of Lading Name",{
          :data_type=>:string,
          :import_lambda => lambda {|inv,data| "Port of Lading cannot be set via invoice upload."},
          :export_lambda => lambda {|inv| (inv.entry.blank? || inv.entry.lading_port.blank?) ? "" : inv.entry.lading_port.name},
          :qualified_field_name => "(SELECT name from ports where schedule_k_code = (select lading_port_code from entries where entries.id = broker_invoices.entry_id))"
        }],
        make_broker_invoice_entry_field(55,:bi_cargo_control_number,:cargo_control_number,"Cargo Control Number",:string, lambda{|entry| entry.cargo_control_number}),
        [56,:bi_invoice_number,:invoice_number,"Invoice Number",{:data_type=>:string}],
        [57,:bi_source_system,:source_system,"Source System",{:data_type=>:string,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        make_broker_invoice_entry_field(58,:bi_ent_part_numbers,:part_numbers,"Part Numbers",:text,lambda {|entry| entry.part_numbers}),
        make_broker_invoice_entry_field(59,:bi_ent_commercial_invoice_numbers,:commercial_invoice_numbers,"Commercial Invoice Numbers",:text,lambda {|entry| entry.commercial_invoice_numbers}),
        make_broker_invoice_entry_field(60,:bi_ent_total_gst, :total_gst, "Total GST", :decimal, lambda {|entry| entry.total_gst}),
        make_broker_invoice_entry_field(61,:bi_ent_total_duty_gst, :total_duty_gst, "Total Duty & GST", :decimal, lambda {|entry| entry.total_duty_gst}),
        make_broker_invoice_entry_field(62,:bi_ent_direct_shipment_date, :direct_shipment_date, "Direct Shipment Date", :date, lambda {|entry| entry.direct_shipment_date}),
        make_broker_invoice_entry_field(63,:bi_ent_across_sent_date, :across_sent_date, "ACROSS Sent Date", :datetime, lambda {|entry| entry.across_sent_date}),
        make_broker_invoice_entry_field(64,:bi_ent_pars_ack_date, :pars_ack_date, "PARS ACK Date", :datetime, lambda {|entry| entry.pars_ack_date}),
        make_broker_invoice_entry_field(65,:bi_ent_cadex_accept_date, :cadex_accept_date, "CADEX Accept Date", :datetime, lambda {|entry| entry.cadex_accept_date}),
        make_broker_invoice_entry_field(66,:bi_ent_cadex_sent_date, :cadex_sent_date, "CADEX Sent Date", :datetime, lambda {|entry| entry.cadex_sent_date}),
        make_broker_invoice_entry_field(67,:bi_ent_k84_month, :k84_month, "K84 Month", :integer, lambda {|entry| entry.k84_month}),
        make_broker_invoice_entry_field(68,:bi_ent_exam_ordered_date, :exam_ordered_date, "Exam Ordered Date", :datetime, lambda {|entry| entry.exam_ordered_date})
      ]
      add_fields CoreModule::BROKER_INVOICE_LINE, [
        [1,:bi_line_charge_code,:charge_code,"Charge Code",{:data_type=>:string}],
        [2,:bi_line_charge_description,:charge_description,"Description",{:data_type=>:string}],
        [3,:bi_line_charge_amount,:charge_amount,"Amount",{:data_type=>:decimal}],
        [4,:bi_line_vendor_name,:vendor_name,"Vendor",{:data_type=>:string}],
        [5,:bi_line_vendor_reference,:vendor_reference,"Vendor Reference",{:data_type=>:string}],
        [6,:bi_line_charge_type,:charge_type,"Charge Type",{:data_type=>:string,:can_view_lambda=>lambda {|u| u.company.broker?}}],
        [7,:bi_line_hst_percent,:hst_percent,"HST Percent",{:data_type=>:decimal}]
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
          :qualified_field_name => "(SELECT name from entity_types where entity_types.id = products.entity_type_id)",
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
          :qualified_field_name => "(SELECT name FROM status_rules WHERE status_rules.id = products.status_rule_id)",
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
          :qualified_field_name => "(SELECT COUNT(distinct pcc_cls.id) FROM classifications pcc_cls 
            INNER JOIN tariff_records pcc_tr ON pcc_tr.classification_id = pcc_cls.id AND LENGTH( pcc_tr.hts_1 ) > 0 WHERE products.id = pcc_cls.product_id)",
          :data_type => :integer
        }],
        [11,:prod_changed_at, :changed_at, "Last Changed",{:data_type=>:datetime,:history_ignore=>true}],
        [13,:prod_created_at, :created_at, "Created Time",{:data_type=>:datetime,:history_ignore=>true}],
        [14,:prod_first_hts, :prod_first_hts, "First HTS Number", {
          :import_lambda => lambda {|obj,data| "First HTS Number was ignored, must be set at the tariff level."},
          :export_lambda => lambda {|obj| 
            r = ""
            cls = obj.classifications.sort_classification_rank.first
            unless cls.nil?
              t = cls.tariff_records.first
              r = t.hts_1 unless t.nil?
            end
            r.nil? ? "" : r.hts_format
          },
          :qualified_field_name => "(select hts_1 from tariff_records fht inner join classifications fhc on fhc.id = fht.classification_id  where fhc.product_id = products.id and fhc.country_id = (SELECT id from countries ORDER BY ifnull(classification_rank,9999), iso_code ASC LIMIT 1) LIMIT 1)",
          :data_type=>:string,
          :history_ignore=>true
        }],
        [15,:prod_bom_parents,:bom_parents,"BOM - Parents",{
          :data_type=>:string,
          :import_lambda => lambda {|o,d| "Bill of Materials ignored, cannot be changed by upload."},
          :export_lambda => lambda {|product|
            product.parent_products.pluck(:unique_identifier).uniq.sort.join(",")
          },
          :qualified_field_name => "(select group_concat(distinct unique_identifier SEPARATOR ',') FROM bill_of_materials_links INNER JOIN products par on par.id = bill_of_materials_links.parent_product_id where bill_of_materials_links.child_product_id = products.id)"
        }],
        [16,:prod_bom_children,:bom_children,"BOM - Children",{
          :data_type=>:string,
          :import_lambda => lambda {|o,d| "Bill of Materials ignored, cannot be changed by upload."},
          :export_lambda => lambda {|product|
            product.child_products.pluck(:unique_identifier).uniq.sort.join(",")
          },
          :qualified_field_name => "(select group_concat(distinct unique_identifier SEPARATOR ',') FROM bill_of_materials_links INNER JOIN products par on par.id = bill_of_materials_links.child_product_id where bill_of_materials_links.parent_product_id = products.id)"
        }],
        [17, :prod_attachment_count, :attachment_count, "Attachment Count", {
          :import_lambda=>lambda {|obj,data| "Attachment Count ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.respond_to?(:all_attachments) ? obj.all_attachments.count : obj.attachments.count},
          :qualified_field_name=>"((select count(*) from attachments where attachable_type = 'Product' and attachable_id = products.id) + (select count(*) from linked_attachments where attachable_type = 'Product' and attachable_id = products.id))",
          :data_type=>:integer
        }]
      ]
      add_fields CoreModule::PRODUCT, [make_last_changed_by(12,'prod',Product)]
      add_fields CoreModule::PRODUCT, make_vendor_arrays(5,"prod","products")
      add_fields CoreModule::PRODUCT, make_division_arrays(100,"prod","products")
      add_fields CoreModule::PRODUCT, make_master_setup_array(200,"prod")
      add_fields CoreModule::PRODUCT, make_importer_arrays(250,"prod","products")
      add_fields CoreModule::PRODUCT, make_sync_record_arrays(300,'prod','products','Product')
      
      add_fields CoreModule::CLASSIFICATION, [
        [1,:class_comp_cnt, :comp_count, "Component Count", {
          :import_lambda => lambda {|obj,data| return "Component Count was ignored. (read only)"},
          :export_lambda => lambda {|obj| obj.tariff_records.size },
          :qualified_field_name => "(select count(id) from tariff_records tr where tr.classification_id = classifications.id)",
          :data_type => :integer,
          :history_ignore=>true
        }],
        [2,:class_updated_at, :updated_at, "Last Changed",{:data_type=>:datetime,:history_ignore=>true}]
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
        },],
        [4,:ord_cust_ord_no, :customer_order_number, "Customer Order Number"],
        [5,:ord_last_exported_from_source,:last_exported_from_source,"System Extract Date",{:data_type=>:datetime}],
        [6,:ord_mode, :mode, "Mode of Transport",{:data_type=>:string}],
        [7,:ord_rule_state,:rule_state,"Business Rule State",{:data_type=>:string,
          :import_lambda=>lambda {|o,d| "Business Rule State ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.business_rules_state },
          :qualified_field_name=> "(select state 
            from business_validation_results bvr 
            where bvr.validatable_type = 'Order' and bvr.validatable_id = orders.id 
            order by (
            case bvr.state
                when 'Fail' then 0
                when 'Review' then 1
                when 'Pass' then 2
                when 'Skipped' then 3
                else 4
            end
            )
            limit 1)"
        }]
      ]
      add_fields CoreModule::ORDER, make_vendor_arrays(100,"ord","orders")
      add_fields CoreModule::ORDER, make_ship_to_arrays(200,"ord","orders")
      add_fields CoreModule::ORDER, make_division_arrays(300,"ord","orders")
      add_fields CoreModule::ORDER, make_master_setup_array(400,"ord")
      add_fields CoreModule::ORDER, make_importer_arrays(500,"ord","orders")

      add_fields CoreModule::ORDER_LINE, [
        [1,:ordln_line_number,:line_number,"Order - Row",{:data_type=>:integer}],
        [3,:ordln_ordered_qty,:quantity,"Order Quantity",{:data_type=>:decimal}],
        [4,:ordln_ppu,:price_per_unit,"Price / Unit",{:data_type=>:decimal}],
        [5,:ordln_ms_state,:state,"Milestone State",{:data_type=>:string,
          :import_lambda => lambda {|obj,data| return "Milestone State was ignored. (read only)"},
          :export_lambda => lambda {|obj| obj.worst_milestone_state },
          :qualified_field_name => "(SELECT IFNULL(milestone_forecast_sets.state,'') as ms_state FROM milestone_forecast_sets INNER JOIN piece_sets on piece_sets.id = milestone_forecast_sets.piece_set_id WHERE piece_sets.order_line_id = order_lines.id ORDER BY FIELD(milestone_forecast_sets.state,'Achieved','Pending','Unplanned','Missed','Trouble','Overdue') DESC LIMIT 1)"
        }],
        [6,:ordln_currency,:currency,"Currency",{data_type: :string}],
        [7,:ordln_country_of_origin,:country_of_origin,"Country of Origin",{data_type: :string}],
        [8,:ordln_hts,:hts,"HTS Code",{data_type: :string,
          :export_lambda=> lambda{|obj| obj.hts.blank? ? '' : obj.hts.hts_format}
        }]
      ]
      add_fields CoreModule::ORDER_LINE, make_product_arrays(100,"ordln","order_lines")

      add_fields CoreModule::SHIPMENT, [
        [1,:shp_ref,:reference,"Reference Number",{:data_type=>:string}],
        [2,:shp_mode,:mode,"Mode",{:data_type=>:string}],
        [3,:shp_master_bill_of_lading,:master_bill_of_lading,"Master Bill of Lading",{:data_type=>:string}],
        [4,:shp_house_bill_of_lading,:house_bill_of_lading,"House Bill of Lading",{:data_type=>:string}],
        [5,:shp_booking_number,:booking_number,"Booking Number",{:data_type=>:string}],
        [6,:shp_receipt_location,:receipt_location,"Freight Receipt Location",{:data_type=>:string}],
        [11,:shp_freight_terms,:freight_terms,"Freight Terms",{:data_type=>:string}],
        [12,:shp_lcl,:lcl,"LCL",{:data_type=>:boolean}],
        [13,:shp_shipment_type,:shipment_type,"Shipment Type",{:data_type=>:string}],
        [14,:shp_booking_shipment_type,:booking_shipment_type,"Shipment Type - Booked",{:data_type=>:string}]       ,
        [15,:shp_booking_mode,:booking_mode,"Mode - Booked",{:data_type=>:string}],
        [16,:shp_vessel,:vessel,"Vessel",{:data_type=>:string}],
        [17,:shp_voyage,:voyage,"Voyage",{:data_type=>:string}],
        [18,:shp_vessel_carrier_scac,:vessel_carrier_scac,"Vessel SCAC",{:data_type=>:string}],
        [19,:shp_booking_received_date,:booking_received_date,"Booking Received Date",{:data_type=>:date}],
        [20,:shp_booking_confirmed_date,:booking_confirmed_date,"Booking Confirmed Date",{:data_type=>:date}],
        [21,:shp_booking_cutoff_date,:booking_cutoff_date,"Cutoff Date",{:data_type=>:date}],
        [22,:shp_booking_est_arrival_date,:booking_est_arrival_date,"Est Arrival Date - Booked",{:data_type=>:date}],
        [23,:shp_booking_est_departure_date,:booking_est_departure_date,"Est Departure Date - Booked",{:data_type=>:date}],
        [24,:shp_docs_received_date,:docs_received_date,"Docs Received Date",{:data_type=>:date}],
        [25,:shp_cargo_on_hand_date,:cargo_on_hand_date,"Cargo On Hand Date",{:data_type=>:date}],
        [26,:shp_est_departure_date,:est_departure_date,"Est Departure Date",{:data_type=>:date}],
        [27,:shp_departure_date,:departure_date,"Departure Date",{:data_type=>:date}],
        [28,:shp_est_arrival_port_date,:est_arrival_port_date,"Est Arrival Date",{:data_type=>:date}],
        [29,:shp_arrival_port_date,:arrival_port_date,"Arrival Date",{:data_type=>:date}],
        [30,:shp_est_delivery_date,:est_delivery_date,"Est Delivery Date",{:data_type=>:date}],
        [31,:shp_delivered_date,:delivered_date,"Delivered Date",{:data_type=>:date}]
      ]
      add_fields CoreModule::SHIPMENT, make_vendor_arrays(100,"shp","shipments")
      add_fields CoreModule::SHIPMENT, make_ship_to_arrays(200,"shp","shipments")
      add_fields CoreModule::SHIPMENT, make_ship_from_arrays(250,"shp","shipments")
      add_fields CoreModule::SHIPMENT, make_carrier_arrays(300,"shp","shipments")
      add_fields CoreModule::SHIPMENT, make_master_setup_array(400,"shp")
      add_fields CoreModule::SHIPMENT, make_importer_arrays(500,"shp","shipments")
      
      add_fields CoreModule::SHIPMENT_LINE, [
        [1,:shpln_line_number,:line_number,"Shipment - Row",{:data_type=>:integer}],
        [2,:shpln_shipped_qty,:quantity,"Shipment Row Quantity",{:data_type=>:decimal}],
        [3,:shpln_container_number,:container_number,"Container Number",{data_type: :string,
          export_lambda: lambda {|sl| sl.container ? sl.container.container_number : ''},
          import_lambda: lambda {|o,d| "Container Number cannot be set via import."},
          qualified_field_name: "(SELECT container_number FROM containers WHERE containers.id = shipment_lines.container_id)"
          }],
        [4,:shpln_container_size,:container_size,"Container Size",{data_type: :string,
          export_lambda: lambda {|sl| sl.container ? sl.container.container_size : ''},
          import_lambda: lambda {|o,d| "Container Size cannot be set via import."},
          qualified_field_name: "(SELECT container_size FROM containers WHERE containers.id = shipment_lines.container_id)"
          }],
        [5,:shpln_container_uid,:container_id,"Container Unique ID",{data_type: :integer,
          import_lambda: lambda {|sl,id| 
            con = Container.find_by_id id
            return "Container with ID #{id} not found. Ignored." unless con
            return "#{ModelField.find_by_uid(:shpln_container_uid).label} is not part of this shipment and was ignored." unless con.shipment_id == sl.shipment_id
            sl.container_id = con.id
            "#{ModelField.find_by_uid(:shpln_container_uid).label} set to #{con.id}."
          }
          }]
      ]
      add_fields CoreModule::SHIPMENT_LINE, make_product_arrays(100,"shpln","shipment_lines")

      add_fields CoreModule::CONTAINER, [
        [1,:con_uid,:id,"Unique ID",{data_type: :string}],
        [2,:con_container_number,:container_number,"Container Number",{data_type: :string}],
        [3,:con_container_size,:container_size,"Size",{data_type: :string}],
        [4,:con_size_description,:size_description,"Size Description",{data_type: :string}],
        [5,:con_weight,:weight,"Weight",{data_type: :string}],
        [6,:con_seal_number,:seal_number,"Seal Number",{data_type: :string}],
        [7,:con_teus,:teus,"TEUs",{data_type: :integer}],
        [8,:con_fcl_lcl,:fcl_lcl,"Full Container",{data_type: :string}],
        [9,:con_quantity,:quantity,"AMS Qauntity",{data_type: :integer}],
        [10,:con_uom,:uom,"AMS UOM",{data_type: :string}]
      ]

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
      add_fields CoreModule::SALE_LINE, make_product_arrays(100,"soln","sales_order_lines")
      
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
      add_region_fields
      add_country_hts_fields
    end
  end

  reload #does the reload when the class is loaded the first time 

  def self.find_by_uid(uid,dont_retry=false)
    return ModelField.new(10000,:_blank,nil,nil,{
      :label_override => "[blank]",
      :import_lambda => lambda {|o,d| "Field ignored"},
      :export_lambda => lambda {|o| },
      :data_type => :string,
      :qualified_field_name => "\"\""
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
  
  #DEPRECATED use find_by_core_module
  def self.find_by_module_type(type_symbol)
    reload_if_stale
    h = MODEL_FIELDS[type_symbol]
    h.nil? ? [] : h.values.to_a
  end

  #get an array of model fields given core module
  def self.find_by_core_module cm
    find_by_module_type cm.class_name.to_sym
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
    return if ModelField.web_mode #see documentation at web_mode accessor
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
