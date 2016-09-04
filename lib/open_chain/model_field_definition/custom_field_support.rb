# supporting methods for ModelField to create the custom field objects
module OpenChain; module ModelFieldDefinition; module CustomFieldSupport
  def add_custom_fields(core_module,base_class)
    base_class.new.custom_definitions.each_with_index do |d,index|
      create_and_insert_custom_field(d, core_module, next_index_number(core_module))
    end
  end

  def build_address_fields custom_definition, core_module, index
    fields_to_add = []
    uid_prefix = "*af_#{custom_definition.id}_"

    #name
    fields_to_add << ModelField.new(index, "#{uid_prefix}name", core_module, "#{uid_prefix}name", {
      custom_id: custom_definition.id,
      label_override: "#{custom_definition.label} (Name)",
      qualified_field_name: "(SELECT addresses.name FROM addresses WHERE addresses.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} and customizable_type = '#{custom_definition.module_type}'))",
      definition: custom_definition.definition,
      read_only: true,
      data_type: :string,
      field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
      address_field: true,
      export_lambda: lambda {|obj|
        r = ""
        id = obj.get_custom_value(custom_definition).value
        if id
          a = Address.find_by_id(id)
          r = a.name if a
        end
        return r
      },
      restore_field: false
    })

    #city
    fields_to_add << ModelField.new(index + 1, "#{uid_prefix}city", core_module, "#{uid_prefix}city", {
      custom_id: custom_definition.id,
      label_override: "#{custom_definition.label} (City)",
      qualified_field_name: "(SELECT addresses.city FROM addresses WHERE addresses.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} and customizable_type = '#{custom_definition.module_type}'))",
      definition: custom_definition.definition,
      read_only: true,
      data_type: :string,
      field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
      address_field: true,
      export_lambda: lambda {|obj|
        r = ""
        id = obj.get_custom_value(custom_definition).value
        if id
          a = Address.find_by_id(id)
          r = a.city if a
        end
        return r
      },
      restore_field: false
    })

    #state
    fields_to_add << ModelField.new(index + 2, "#{uid_prefix}state", core_module, "#{uid_prefix}state", {
      custom_id: custom_definition.id,
      label_override: "#{custom_definition.label} (State)",
      qualified_field_name: "(SELECT addresses.state FROM addresses WHERE addresses.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} and customizable_type = '#{custom_definition.module_type}'))",
      definition: custom_definition.definition,
      read_only: true,
      data_type: :string,
      field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
      address_field: true,
      export_lambda: lambda {|obj|
        r = ""
        id = obj.get_custom_value(custom_definition).value
        if id
          a = Address.find_by_id(id)
          r = a.state if a
        end
        return r
      },
      restore_field: false
    })

    #postal code
    fields_to_add << ModelField.new(index + 2, "#{uid_prefix}postal_code", core_module, "#{uid_prefix}postal_code", {
      custom_id: custom_definition.id,
      label_override: "#{custom_definition.label} (Postal Code)",
      qualified_field_name: "(SELECT addresses.postal_code FROM addresses WHERE addresses.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} and customizable_type = '#{custom_definition.module_type}'))",
      definition: custom_definition.definition,
      read_only: true,
      data_type: :string,
      field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
      address_field: true,
      export_lambda: lambda {|obj|
        r = ""
        id = obj.get_custom_value(custom_definition).value
        if id
          a = Address.find_by_id(id)
          r = a.postal_code if a
        end
        return r
      },
      restore_field: false
    })

    #country iso code
    fields_to_add << ModelField.new(index + 3, "#{uid_prefix}iso_code", core_module, "#{uid_prefix}iso_code", {
      custom_id: custom_definition.id,
      label_override: "#{custom_definition.label} (Country ISO)",
      qualified_field_name: "(SELECT countries.iso_code FROM addresses INNER JOIN countries ON addresses.country_id = countries.id WHERE addresses.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} and customizable_type = '#{custom_definition.module_type}'))",
      definition: custom_definition.definition,
      read_only: true,
      data_type: :string,
      field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
      address_field: true,
      export_lambda: lambda {|obj|
        r = ""
        id = obj.get_custom_value(custom_definition).value
        if id
          a = Address.find_by_id(id)
          if a
            c = a.country
            r = c.iso_code if c
          end
        end
        return r
      },
      restore_field: false
    })

    #add the street field, concatenating lines 1 -3
    fields_to_add << ModelField.new(index + 4, "#{uid_prefix}street", core_module, "#{uid_prefix}street", {
      custom_id: custom_definition.id,
      label_override: "#{custom_definition.label} (Street)",
      qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(addresses.line_1, ''), IFNULL(addresses.line_2, ''), IFNULL(addresses.line_3, '')) FROM addresses WHERE addresses.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} and customizable_type = '#{custom_definition.module_type}'))",
      definition: custom_definition.definition,
      read_only: true,
      data_type: :string,
      field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
      address_field: true,
      export_lambda: lambda {|obj|
        r = ""
        id = obj.get_custom_value(custom_definition).value
        if id
          a = Address.find_by_id(id)
          if a
            ary = []
            [a.line_1,a.line_2,a.line_3].each {|ln| ary << ln unless ln.blank?}
            r = ary.join(' ').strip
          end
        end
        return r
      },
      restore_field: false
    })

    #add the base field
    fld = custom_definition.model_field_uid.to_sym
    fields_to_add << ModelField.new(index + 5,fld,core_module,fld,{:custom_id=>custom_definition.id,:label_override=>"#{custom_definition.label}",
      :qualified_field_name=>"(SELECT #{custom_definition.data_column} FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} AND customizable_type = '#{custom_definition.module_type}')",
      :definition => custom_definition.definition, :default_label => "#{custom_definition.label} Unique ID", address_field: true
    })
    fields_to_add
  end

  def build_user_fields custom_definition, core_module, index
    fields_to_add = []
    fld = custom_definition.model_field_uid.to_sym
    uid_prefix = "*uf_#{custom_definition.id}_"
    fields_to_add << ModelField.new(index, "#{uid_prefix}username", core_module, "#{uid_prefix}username", {
      custom_id: custom_definition.id,
      label_override: "#{custom_definition.label} (Username)",
      qualified_field_name: "(SELECT users.username FROM users WHERE users.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} AND customizable_type = '#{custom_definition.module_type}'))",
      definition: custom_definition.definition,
      import_lambda: lambda {|obj,data|
        user_id = nil
        u = User.find_by_username data
        user_id = u.id if u
        obj.get_custom_value(custom_definition).value = user_id
        return "#{custom_definition.label} set to #{u.nil? ? 'BLANK' : u.username}"
      },
      export_lambda: lambda {|obj|
        r = ""
        cv = obj.get_custom_value(custom_definition)
        user_id = cv.value
        if user_id
          u = User.find_by_id user_id
          r = u.username if u
        end
        return r
      },
      data_type: :string,
      field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
      user_field: true,
      restore_field: false
    })
    fields_to_add << ModelField.new(index, "#{uid_prefix}fullname", core_module, "#{uid_prefix}fullname", {
      custom_id: custom_definition.id,
      label_override: "#{custom_definition.label} (Name)",
      qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(first_name, ''), IFNULL(last_name, '')) FROM users WHERE users.id = (SELECT integer_value FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} AND customizable_type = '#{custom_definition.module_type}'))",
      definition: custom_definition.definition,
      import_lambda: lambda {|obj,data|
        return "#{custom_definition.label} cannot be imported by full name, try the username field."
      },
      export_lambda: lambda {|obj|
        r = ""
        cv = obj.get_custom_value(custom_definition)
        user_id = cv.value
        if user_id
          u = User.find_by_id user_id
          r = u.full_name if u
        end
        return r
      },
      data_type: :string,
      field_validator_rule: ModelField.field_validator_rule(custom_definition.model_field_uid),
      read_only: true,
      user_field: true,
      user_full_name_field: true,
      restore_field: false
    })
    fields_to_add << ModelField.new(index,fld,core_module,fld,{:custom_id=>custom_definition.id,:label_override=>"#{custom_definition.label}",
      :qualified_field_name=>"(SELECT #{custom_definition.data_column} FROM custom_values WHERE customizable_id = #{core_module.table_name}.id AND custom_definition_id = #{custom_definition.id} AND customizable_type = '#{custom_definition.module_type}')",
      :definition => custom_definition.definition, :default_label => "#{custom_definition.label}",
      :read_only => true,
      :user_id_field => true
    })
    fields_to_add
  end

  # Add all Product Custom Definitions to given module
  def create_and_insert_product_custom_fields core_module, cd_cache
    start_index = next_index_number core_module
    prod_defs = []
    if cd_cache.empty?
      prod_defs = CustomDefinition.where(module_type:'Product').to_a
    else
      prod_defs = cd_cache.values.collect {|cd| cd.is_a?(CustomDefinition) && cd.module_type=='Product' ? cd : nil}.compact
    end
    prod_defs.each_with_index {|d,i| create_and_insert_product_custom_field d, core_module, start_index+i}
  end

  # Make a ModelField based on the given module that links through
  # to a product custom definition.
  def create_and_insert_product_custom_field custom_definition, core_module, index
    uid = "#{custom_definition.model_field_uid}_#{core_module.table_name}".to_sym
    mf = ModelField.new(index,uid,core_module,uid,{
      custom_id: custom_definition.id,
      label_override: "Product - #{custom_definition.label.to_s}",
      qualified_field_name: "(SELECT #{custom_definition.data_column} FROM products INNER JOIN custom_values ON custom_values.customizable_id = products.id AND custom_values.customizable_type = 'Product' and custom_values.custom_definition_id = #{custom_definition.id} WHERE products.id = #{core_module.table_name}.product_id)",
      definition: custom_definition.definition,
      default_label: custom_definition.label.to_s,
      read_only: true,
      export_lambda: lambda { |o|
        p = o.product
        return nil if p.nil?
        p.get_custom_value(custom_definition).value
      }
    })
    add_model_fields core_module, [mf]
    mf
  end

  def create_and_insert_variant_custom_fields core_module, cd_cache
    start_index = next_index_number core_module
    defs = []
    if cd_cache.empty?
      defs = CustomDefinition.where(module_type:'Variant').to_a
    else
      defs = cd_cache.values.collect {|cd| cd.is_a?(CustomDefinition) && cd.module_type=='Variant' ? cd : nil}.compact
    end
    defs.each_with_index {|d,i| create_and_insert_variant_custom_field d, core_module, start_index+i}
  end

  # Make a ModelField based on the given module that links through
  # to a variant custom definition.
  def create_and_insert_variant_custom_field custom_definition, core_module, index
    uid = "#{custom_definition.model_field_uid}_#{core_module.table_name}".to_sym
    mf = ModelField.new(index,uid,core_module,uid,{
      custom_id: custom_definition.id,
      label_override: "Variant - #{custom_definition.label.to_s}",
      qualified_field_name: "(SELECT #{custom_definition.data_column} FROM variants INNER JOIN custom_values ON custom_values.customizable_id = variants.id AND custom_values.customizable_type = 'Variant' and custom_values.custom_definition_id = #{custom_definition.id} WHERE variants.id = #{core_module.table_name}.variant_id)",
      definition: custom_definition.definition,
      default_label: custom_definition.label.to_s,
      read_only: true,
      export_lambda: lambda { |o|
        v = o.variant
        return nil if v.nil?
        v.get_custom_value(custom_definition).value
      }
    })
    add_model_fields core_module, [mf]
    mf
  end

end; end; end
