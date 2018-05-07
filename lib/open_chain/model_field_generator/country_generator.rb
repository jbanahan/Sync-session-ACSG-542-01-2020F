module OpenChain; module ModelFieldGenerator; module CountryGenerator
  def make_country_arrays(rank_start, uid_prefix, table_name, association_name, association_title: nil, country_selector: nil)
    foreign_key = "#{association_name}_id"
    association_title = association_title.blank? ? "" : "#{association_title} "

    r = []
    r << [rank_start,"#{uid_prefix}_cntry_name".to_sym, :name,"#{association_title}Country Name", {
      :import_lambda => lambda {|detail,data|
        c = Country.where(:name => data).first
        detail.public_send("#{association_name}=".to_sym, c)
        unless c.nil?
          return "#{association_title}Country set to #{c.name}"
        else
          return "#{association_title}Country not found with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| detail.public_send("#{association_name}".to_sym).try(:name)},
      :qualified_field_name=>"(SELECT name from countries where countries.id = #{table_name}.#{foreign_key})",
      :data_type=>:string,
      :history_ignore=>true
    }]
    r << [rank_start+1,"#{uid_prefix}_cntry_iso".to_sym, :iso_code, "#{association_title}Country ISO Code",{
      :import_lambda => lambda {|detail,data|
        c = Country.where(:iso_code => data).first
        detail.public_send("#{association_name}=".to_sym, c)
        unless c.nil?
          return "#{association_title}Country set to #{c.name}"
        else
          return "#{association_title}Country not found with ISO Code \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| detail.public_send("#{association_name}".to_sym).try(:iso_code)},
      :qualified_field_name=>"(SELECT iso_code from countries where countries.id = #{table_name}.#{foreign_key})",
      :data_type=>:string
    }]
    r << [rank_start+2,"#{uid_prefix}_cntry_id".to_sym, :country_id, "#{association_title}Country",{
      import_lambda:  lambda {|detail, data|
        c = Country.where(id: data).first
        detail.public_send("#{association_name}=".to_sym, c)
        unless c.nil?
          return "#{association_title}Country set to #{c.name}"
        else
          return "#{association_title}Country not found with ID \"#{data}\""
        end
      },
      export_lambda: lambda {|detail| detail.public_send(foreign_key.to_sym) },
      data_type: :integer,
      history_ignore: true,
      user_accessible: false,
      select_options_lambda: country_selector
    }]
    r
  end
end; end; end
