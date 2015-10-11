module OpenChain; module ModelFieldGenerator; module CountryGenerator
  def make_country_arrays(rank_start,uid_prefix,table_name,join='country')
    foreign_key = "#{join}_id"
    r = []
    r << [rank_start,"#{uid_prefix}_cntry_name".to_sym, :name,"Country Name", {
      :import_lambda => lambda {|detail,data|
        c = Country.where(:name => data).first
        eval "detail.#{join} = c"
        unless c.nil?
          return "Country set to #{c.name}"
        else
          return "Country not found with name \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| eval "detail.#{join}.nil? ? '' : detail.#{join}.name"},
      :qualified_field_name=>"(SELECT name from countries where countries.id = #{table_name}.#{foreign_key})",
      :data_type=>:string,
      :history_ignore=>true
    }]
    r << [rank_start+1,"#{uid_prefix}_cntry_iso".to_sym, :iso_code, "Country ISO Code",{
      :import_lambda => lambda {|detail,data|
        c = Country.where(:iso_code => data).first
        eval "detail.#{join} = c"
        unless c.nil?
          return "Country set to #{c.name}"
        else
          return "Country not found with ISO Code \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail| eval "detail.#{join}.nil? ? '' : detail.#{join}.iso_code"},
      :qualified_field_name=>"(SELECT iso_code from countries where countries.id = #{table_name}.#{foreign_key})",
      :data_type=>:string
    }]
    r << [rank_start+2,"#{uid_prefix}_cntry_id".to_sym, :country_id, "Country ID",{
      :import_lambda => lambda {|detail, data|
        c = Country.where(id: data).first
        eval "detail.#{join} = c"
        unless c.nil?
          return "Country set to #{c.name}"
        else
          return "Country not found with ISO Code \"#{data}\""
        end
      },
      :export_lambda => lambda {|detail|  eval "detail.#{join}.nil? ? nil : detail.#{join}.id"},
      :data_type=>:integer,
      :history_ignore=>true,
      :user_accessible => false
    }]
    r
  end
end; end; end
