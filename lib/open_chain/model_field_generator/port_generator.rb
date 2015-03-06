module OpenChain; module ModelFieldGenerator; module PortGenerator
  def make_port_arrays(rank_start,uid_prefix,table_name,join_field,name_prefix)
    r_count = rank_start
    r = []
    r << [r_count,"#{uid_prefix}_id".to_sym, "#{join_field}_id".to_sym, "#{name_prefix} ID",{
        data_type: :integer,
        history_ignore: true
      }]
    r << [r_count,"#{uid_prefix}_name".to_sym, :name, "#{name_prefix} Name",{
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
    r_count += 1
    r
  end
end; end; end
