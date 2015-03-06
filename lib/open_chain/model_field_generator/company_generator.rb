module OpenChain; module ModelFieldGenerator; module CompanyGenerator
  def make_company_arrays(rank_start,uid_prefix,table_name,short_prefix,description,association_name)
    # The id field is created pretty much solely so the screens can make select boxes using the id as the value parameter
    # and reference the field like prod_imp_id.
    r = [
      [rank_start,"#{uid_prefix}_#{short_prefix}_id".to_sym,"#{association_name}_id".to_sym,"#{description} Name",{:history_ignore=>true, user_accessible: false}]
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
  def make_carrier_arrays(rank_start,uid_prefix,table_name)
    make_company_arrays rank_start, uid_prefix, table_name, "car", "Carrier", "carrier"
  end
  def make_customer_arrays(rank_start,uid_prefix,table_name)
    make_company_arrays rank_start, uid_prefix, table_name, "cust", "Customer", "customer"
  end
  def make_vendor_arrays(rank_start,uid_prefix,table_name)
    make_company_arrays rank_start, uid_prefix, table_name, "ven", "Vendor", "vendor"
  end
  def make_importer_arrays(rank_start,uid_prefix,table_name)
    make_company_arrays rank_start, uid_prefix, table_name, "imp", "Importer", "importer"
  end
  def make_agent_arrays(rank_start,uid_prefix,table_name)
    make_company_arrays rank_start, uid_prefix, table_name, 'agent', 'Agent', 'agent'
  end
  def make_factory_arrays(rank_start,uid_prefix,table_name)
    make_company_arrays rank_start, uid_prefix, table_name, 'factory', 'Factory', 'factory'
  end
end; end; end
