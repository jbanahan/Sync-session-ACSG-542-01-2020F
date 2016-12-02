module OpenChain; module ModelFieldGenerator; module PortGenerator
  def make_port_arrays(rank_start,uid_prefix,table_name,join_field,name_prefix,port_selector:nil)
    r_count = rank_start
    r = []
    id_hash = {
      data_type: :integer,
      history_ignore: true
    }
    if port_selector
      id_hash[:select_options_lambda] = lambda {
        port_selector.collect {|p| [p.id,p.name]}
      }
    end
    r << [r_count,"#{uid_prefix}_id".to_sym, "#{join_field}_id".to_sym, "#{name_prefix} DB ID",id_hash]
    r << [r_count+r.size,"#{uid_prefix}_name".to_sym, :name, "#{name_prefix} Name",{
        import_lambda: lambda {|obj,data|
          p = Port.find_by_name(data)
          if p
            eval "obj.#{join_field}= p"
            return "#{name_prefix} set to #{p.name}"
          else
            return "Port with name \"#{data}\" not found."
          end
        },
        export_lambda: lambda {|obj|
          to_eval = "obj.#{join_field}.nil? ? '' : obj.#{join_field}.name"
          eval to_eval
        },
        qualified_field_name: "(SELECT name FROM ports WHERE #{table_name}.#{join_field}_id = ports.id)",
        data_type: 'string'
      }]
    r
  end
end; end; end
