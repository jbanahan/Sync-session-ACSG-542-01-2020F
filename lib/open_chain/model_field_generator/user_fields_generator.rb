module OpenChain; module ModelFieldGenerator; module UserFieldsGenerator

  def make_user_fields starting_id, uid_prefix, base_label, core_module, association_name, table_name: core_module.table_name, sql_column_name: nil, attribute_name: nil
    fields_to_add = []

    sql_column_name = association_name.to_s + "_id" if sql_column_name.blank?
    attribute_name = sql_column_name if attribute_name.blank?

    
    fields_to_add << [starting_id, "#{uid_prefix}_username".to_sym, "#{uid_prefix}_username".to_sym, "#{base_label} (Username)", {
      qualified_field_name: "(SELECT users.username FROM users INNER JOIN #{table_name} username_sq ON username_sq.#{sql_column_name} = users.id WHERE username_sq.id = #{table_name}.id)",
      import_lambda: lambda {|obj, data|
        u = User.where(username: data.to_s).first
        obj.public_send("#{association_name}=".to_sym, u)
        return "#{base_label} set to #{u.nil? ? 'BLANK' : u.username}"
      }, 
      export_lambda: lambda {|obj|
        u = obj.public_send(association_name.to_sym)
        u.nil? ? nil : u.username
      },
      data_type: :string, user_field: true, restore_field: false
    }]

    fields_to_add << [starting_id += 1, "#{uid_prefix}_fullname".to_sym, "#{uid_prefix}_fullname".to_sym, "#{base_label} (Name)", {
      qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(first_name, ''), IFNULL(last_name, '')) FROM users INNER JOIN #{table_name} fullname_sq ON fullname_sq.#{sql_column_name} = users.id WHERE fullname_sq.id = #{table_name}.id)",
      import_lambda: lambda {|obj, data|
        return "#{base_label} cannot be imported by full name, try the username field."
      }, 
      export_lambda: lambda {|obj|
        u = obj.public_send(association_name.to_sym)
        u.nil? ? nil : u.full_name
      },
      data_type: :string, user_field: true, user_full_name_field: true, restore_field: false, read_only: true
    }]

    fields_to_add << [starting_id += 1, uid_prefix.to_sym, attribute_name.to_sym, base_label, { data_type: :integer, read_only: true, user_id_field: true }]


    fields_to_add
  end

end; end; end