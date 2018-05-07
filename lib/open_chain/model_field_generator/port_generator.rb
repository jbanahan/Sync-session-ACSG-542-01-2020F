module OpenChain; module ModelFieldGenerator; module PortGenerator
  def make_port_arrays(rank_start,uid_prefix,table_name,join_field,name_prefix,port_selector:nil)
    r_count = rank_start
    r = []
    id_hash = {
      data_type: :integer,
      history_ignore: true,
      user_accessible: false, 
      import_lambda: lambda {|obj, data|
        p = Port.where(id: data).first
        if p
          obj.public_send("#{join_field}=".to_sym, p)
          return "#{name_prefix} set to #{p.name}"
        else
          return "Port with id #{data} not found."
        end
      },
      qualified_field_name: "(SELECT id FROM ports WHERE #{table_name}.#{join_field}_id = ports.id)"
    }
    if port_selector
      id_hash[:select_options_lambda] = port_selector
    end
    r << [r_count,"#{uid_prefix}_id".to_sym, "#{join_field}_id".to_sym, "#{name_prefix}",id_hash]
    r << [r_count+1,"#{uid_prefix}_name".to_sym, :name, "#{name_prefix} Name",{
        import_lambda: lambda {|o,d| "#{name_prefix} is read only."},
        export_lambda: lambda {|obj|
          val = obj.public_send(join_field)
          val.nil? ? '' : val.name.to_s
        },
        qualified_field_name: "(SELECT name FROM ports WHERE #{table_name}.#{join_field}_id = ports.id)",
        data_type: :string,
        read_only: true
      }]
    r << [r_count+1, "#{uid_prefix}_code".to_sym, :code, "#{name_prefix} Code",{
        import_lambda: lambda {|o,d| "#{name_prefix} is read only."},
        export_lambda: lambda {|obj|
          port = obj.public_send(join_field)

          port.nil? ? '' : port.search_friendly_port_code(trim_cbsa: false).to_s
        },
        qualified_field_name: "(SELECT IFNULL(schedule_d_code, IFNULL(schedule_k_code, IFNULL(unlocode, IFNULL(cbsa_port, null)))) FROM ports WHERE #{table_name}.#{join_field}_id = ports.id)",
        data_type: :string,
        read_only: true,
        history_ignore: true
      }]
    r
  end
end; end; end
