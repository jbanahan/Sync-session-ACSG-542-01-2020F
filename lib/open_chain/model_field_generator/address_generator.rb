module OpenChain; module ModelFieldGenerator; module AddressGenerator
  def make_ship_arrays(rank_start, uid_prefix, table_name, from_to)
    raise "Invalid shipping from/to indicator provided: #{from_to}" unless ["from", "to"].include?(from_to)
    name = "Ship #{from_to.titleize}"
    attribute = "ship_#{from_to}"

    r = [
      [rank_start, :"#{uid_prefix}_#{attribute}_id", "#{attribute}_id", "#{name} Address", {data_type: :integer, user_accessible:false, address_field: true, address_field_id: true}],
      [rank_start+1, :"#{uid_prefix}_#{attribute}_name", :"#{attribute}_name", "#{name} (Name)", {
         data_type: :string,
         read_only:true,
         export_lambda: lambda {|obj| obj.send("#{attribute}").try(:name) },
         address_field: true,
         qualified_field_name: "(SELECT name FROM addresses WHERE addresses.id = #{table_name}.#{attribute}_id)"
      }],
      [rank_start+2, :"#{uid_prefix}_#{attribute}_city", :"#{attribute}_city", "#{name} (City)", {
         data_type: :string,
         read_only:true,
         export_lambda: lambda {|obj| obj.send("#{attribute}").try(:city) },
         address_field: true,
         qualified_field_name: "(SELECT city FROM addresses WHERE addresses.id = #{table_name}.#{attribute}_id)"
      }],
      [rank_start+3, :"#{uid_prefix}_#{attribute}_state", :"#{attribute}_state", "#{name} (State)", {
         data_type: :string,
         read_only:true,
         export_lambda: lambda {|obj| obj.send("#{attribute}").try(:state) },
         address_field: true,
         qualified_field_name: "(SELECT state FROM addresses WHERE addresses.id = #{table_name}.#{attribute}_id)"
      }],
      [rank_start+4, :"#{uid_prefix}_#{attribute}_postal_code", :"#{attribute}_postal_code", "#{name} (Postal Code)", {
         data_type: :string,
         read_only:true,
         export_lambda: lambda {|obj| obj.send("#{attribute}").try(:postal_code) },
         address_field: true,
         qualified_field_name: "(SELECT postal_code FROM addresses WHERE addresses.id = #{table_name}.#{attribute}_id)"
      }],
      [rank_start+5, :"#{uid_prefix}_#{attribute}_country", :"#{attribute}_country", "#{name} (Country ISO)", {
         data_type: :string,
         read_only:true,
         export_lambda: lambda {|obj| obj.send("#{attribute}").try(:country).try(:iso_code) },
         address_field: true,
         qualified_field_name: "(SELECT countries.iso_code FROM addresses LEFT OUTER JOIN countries on countries.id = addresses.country_id WHERE addresses.id = #{table_name}.#{attribute}_id)"
      }],
      [rank_start+6, :"#{uid_prefix}_#{attribute}_street", :"#{attribute}_street", "#{name} (Street)", {
       data_type: :string,
       read_only:true,
       export_lambda: lambda {|obj|
        address = obj.send("#{attribute}")
        return "" if address.nil?
        [address.line_1, address.line_2, address.line_3].keep_if {|a| !a.blank?}.join(" ").strip
       },
       address_field: true,
       qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(addresses.line_1, ''), IFNULL(addresses.line_2, ''), IFNULL(addresses.line_3, '')) FROM addresses WHERE addresses.id = #{table_name}.#{attribute}_id)"
      }],
      [rank_start+7, :"#{uid_prefix}_#{attribute}_full_address", :"#{attribute}_full_address", "#{name} Address (Full)", {
         data_type: :text,
         read_only: true,
         address_field: true,
         address_field_full: true,
         export_lambda: lambda {|obj| obj.send("#{attribute}").try(:full_address)},
         qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(addresses.name, ''), '\n', IFNULL(addresses.line_1, ''), IFNULL(addresses.line_2, ''), IFNULL(addresses.line_3, ''),'\n', IFNULL(addresses.city, ''), IFNULL(addresses.state, ''), IFNULL(addresses.postal_code, ''),'\n',IFNULL(countries.iso_code,''))  FROM addresses LEFT OUTER JOIN countries ON addresses.country_id = countries.id WHERE addresses.id = #{table_name}.#{attribute}_id)"
       }],
      [rank_start+8, :"#{uid_prefix}_#{attribute}_system_code", :"#{attribute}_system_code", "#{name} System Code", {
       read_only:true,
       export_lambda: lambda {|obj| obj.send("#{attribute}").try(:system_code)},
       qualified_field_name: "(SELECT system_code FROM addresses WHERE addresses.id = #{table_name}.#{attribute}_id)",
       data_type: :string
     }]
    ]
  end

  def make_address_arrays(rank_start, uid_prefix, table_name, address_name)
    [[rank_start, :"#{uid_prefix}_#{address_name}_address_id", :"#{address_name}_address_id", "#{address_name.titleize} Address", {data_type: :integer, user_accessible: false, address_field: true, address_field_id: true}],
    [rank_start+1, :"#{uid_prefix}_#{address_name}_address_name", :"#{address_name}_address_name", "#{address_name.titleize} (Name)", {
       data_type: :string,
       read_only:true,
       export_lambda: lambda {|obj| obj.send("#{address_name}_address").try(:name) },
       address_field: true,
       qualified_field_name: "(SELECT name FROM addresses WHERE addresses.id = #{table_name}.#{address_name}_address_id)"
    }],
    [rank_start+2, :"#{uid_prefix}_#{address_name}_address_city", :"#{address_name}_address_city", "#{address_name.titleize} (City)", {
       data_type: :string,
       read_only:true,
       export_lambda: lambda {|obj| obj.send("#{address_name}_address").try(:city) },
       address_field: true,
       qualified_field_name: "(SELECT city FROM addresses WHERE addresses.id = #{table_name}.#{address_name}_address_id)"
    }],
    [rank_start+3, :"#{uid_prefix}_#{address_name}_address_state", :"#{address_name}_address_state", "#{address_name.titleize} (State)", {
       data_type: :string,
       read_only:true,
       export_lambda: lambda {|obj| obj.send("#{address_name}_address").try(:state) },
       address_field: true,
       qualified_field_name: "(SELECT state FROM addresses WHERE addresses.id = #{table_name}.#{address_name}_address_id)"
    }],
    [rank_start+4, :"#{uid_prefix}_#{address_name}_address_postal_code", :"#{address_name}_address_postal_code", "#{address_name.titleize} (Postal Code)", {
       data_type: :string,
       read_only:true,
       export_lambda: lambda {|obj| obj.send("#{address_name}_address").try(:postal_code) },
       address_field: true,
       qualified_field_name: "(SELECT postal_code FROM addresses WHERE addresses.id = #{table_name}.#{address_name}_address_id)"
    }],
    [rank_start+5, :"#{uid_prefix}_#{address_name}_address_country", :"#{address_name}_address_country", "#{address_name.titleize} (Country ISO)", {
       data_type: :string,
       read_only:true,
       export_lambda: lambda {|obj| obj.send("#{address_name}_address").try(:country).try(:iso_code) },
       address_field: true,
       qualified_field_name: "(SELECT countries.iso_code FROM addresses LEFT OUTER JOIN countries on countries.id = addresses.country_id WHERE addresses.id = #{table_name}.#{address_name}_address_id)"
    }],
    [rank_start+6, :"#{uid_prefix}_#{address_name}_address_street", :"#{address_name}_address_street", "#{address_name.titleize} (Street)", {
       data_type: :string,
       read_only:true,
       export_lambda: lambda {|obj|
        address = obj.send("#{address_name}_address")
        return "" if address.nil?
        [address.line_1, address.line_2, address.line_3].keep_if {|a| !a.blank?}.join(" ").strip
       },
       address_field: true,
       qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(addresses.line_1, ''), IFNULL(addresses.line_2, ''), IFNULL(addresses.line_3, '')) FROM addresses where addresses.id = #{table_name}.#{address_name}_address_id)"
    }],
    [rank_start+7, :"#{uid_prefix}_#{address_name}_address_full_address", :"#{address_name}_address", "#{address_name.titleize} Address (Full)", {
       data_type: :text,
       read_only:true,
       address_field: true,
       address_field_full: true,
       export_lambda: lambda {|obj| obj.send("#{address_name}_address").try(:full_address)},
       qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(addresses.name, ''), '\n', IFNULL(addresses.line_1, ''), IFNULL(addresses.line_2, ''), IFNULL(addresses.line_3, ''),'\n', IFNULL(addresses.city, ''), IFNULL(addresses.state, ''), IFNULL(addresses.postal_code, ''),'\n',IFNULL(countries.iso_code,''))  FROM addresses LEFT OUTER JOIN countries ON addresses.country_id = countries.id where addresses.id = #{table_name}.#{address_name}_address_id)"
     }]]
  end

  def make_ship_to_arrays(rank_start, uid_prefix, table_name)
    make_ship_arrays(rank_start, uid_prefix, table_name, "to")
  end
  def make_ship_from_arrays(rank_start, uid_prefix, table_name)
    make_ship_arrays(rank_start, uid_prefix, table_name, "from")
  end
end; end; end;
