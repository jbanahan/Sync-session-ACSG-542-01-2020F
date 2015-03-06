module OpenChain; module ModelFieldGenerator; module AddressGenerator
  def make_ship_arrays(rank_start,uid_prefix,table_name,ft)
    raise "Invalid shipping from/to indicator provided: #{ft}" unless ["from","to"].include?(ft)
    ftc = ft.titleize
    r = [
      [rank_start,"#{uid_prefix}_ship_#{ft}_id".to_sym,"ship_#{ft}_id".to_sym,"Ship #{ftc} Name",{history_ignore: true, user_accessible: false}]
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

  def make_ship_to_arrays(rank_start,uid_prefix,table_name)
    make_ship_arrays(rank_start,uid_prefix,table_name,"to")
  end
  def make_ship_from_arrays(rank_start,uid_prefix,table_name)
    make_ship_arrays(rank_start,uid_prefix,table_name,"from")
  end
end; end; end;
