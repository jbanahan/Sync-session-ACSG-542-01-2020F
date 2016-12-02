module OpenChain; module ModelFieldGenerator; module AddressGenerator
  def make_ship_arrays(rank_start,uid_prefix,table_name,ft)
    raise "Invalid shipping from/to indicator provided: #{ft}" unless ["from","to"].include?(ft)
    ftc = ft.titleize
    r = [
      [rank_start,"#{uid_prefix}_ship_#{ft}_id".to_sym,"ship_#{ft}_id".to_sym,"Ship #{ftc} Database ID",{history_ignore: true, data_type: :integer}]
    ]
    r << [rank_start+1,"#{uid_prefix}_ship_#{ft}_name".to_sym,:name,"Ship #{ftc} Name", {
      :read_only => true,
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
    r << [rank_start+2, :"#{uid_prefix}_ship_#{ft}_full_address", :"#ship_{ft}_address", "Ship #{ftc} Address", {
       data_type: :text,
       read_only:true,
       export_lambda: lambda {|obj| obj.send("ship_#{ft}").try(:full_address)},
       qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(line_1, ''), IFNULL(line_2, ''), IFNULL(line_3, '')^',', IFNULL(city, ''), IFNULL(state, ''), IFNULL(postal_code, '')^',', IFNULL(iso_code,'')) FROM addresses INNER JOIN countries ON addresses.country_id = countries.id where addresses.id = #{table_name}.ship_#{ft}_id)"
     }]
    r
  end

  def make_address_arrays(rank_start,uid_prefix,table_name,address_name)
    [[rank_start,:"#{uid_prefix}_#{address_name}_address_id", :"#{address_name}_address_id", "#{address_name.titleize} Address Id",{data_type: :integer, user_accessible: false}],
    [rank_start+1,:"#{uid_prefix}_#{address_name}_address_name", :"#{address_name}_address_name", "#{address_name.titleize} Address Name",{
       data_type: :string,
       read_only:true,
       export_lambda: lambda{|obj| obj.send("#{address_name}_address").try(:name) },
       qualified_field_name: "(SELECT name FROM addresses WHERE addresses.id = #{table_name}.#{address_name}_address_id)"
    }],
    [rank_start+2, :"#{uid_prefix}_#{address_name}_address_full_address", :"#{address_name}_address", "#{address_name.titleize} Address", {
       data_type: :text,
       read_only:true,
       export_lambda: lambda {|obj| obj.send("#{address_name}_address").try(:full_address)},
       qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(line_1, ''), IFNULL(line_2, ''), IFNULL(line_3, '')^',', IFNULL(city, ''), IFNULL(state, ''), IFNULL(postal_code, '')^',', IFNULL(iso_code,'')) FROM addresses INNER JOIN countries ON addresses.country_id = countries.id where addresses.id = #{table_name}.#{address_name}_address_id)"
     }]]
  end

  def make_ship_to_arrays(rank_start,uid_prefix,table_name)
    make_ship_arrays(rank_start,uid_prefix,table_name,"to")
  end
  def make_ship_from_arrays(rank_start,uid_prefix,table_name)
    make_ship_arrays(rank_start,uid_prefix,table_name,"from")
  end
end; end; end;
