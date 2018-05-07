module OpenChain; module ModelFieldGenerator; module CountryHtsGenerator

  def import_lambda product_lambda, hts_number, country
    lambda do |obj, d|
      p = product_lambda.call(obj)

      #validate HTS
      hts = TariffRecord.clean_hts(d)
      return "Blank HTS ignored for #{country.iso_code}" if hts.blank?
      unless OfficialTariff.find_by_country_id_and_hts_code(country.id,hts) || OfficialTariff.where(country_id:country.id).empty?
        e = "#{d} is not valid for #{country.iso_code} HTS #{hts_number}"
        # Indicate the message is an error message
        def e.error?; true; end
        return e;
      end
      cls = nil
      #find classifications & tariff records in memory so this can work on objects that are dirty
      p.classifications.each do |existing|
        cls = existing if existing.country_id == country.id
        break if cls
      end
      cls = p.classifications.build(:country_id=>country.id) unless cls
      tr = nil
      tr = cls.tariff_records.sort {|a,b| a.line_number <=> b.line_number}.first
      tr = cls.tariff_records.build unless tr
      tr.send("hts_#{hts_number}=".to_sym,hts)
      "#{country.iso_code} HTS #{hts_number} set to #{hts.hts_format}"
    end
  end

  def export_lambda product_lambda, hts_number, country
    lambda do |obj|
      p = product_lambda.call(obj)
      return "" if p.nil?

      cls = p.classifications.find {|c| c.country_id == country.id }

      retval = ""
      if cls
        tr = cls.tariff_records[0]
        if tr
          retval = tr.send("hts_#{hts_number}").to_s.hts_format
        end
      end
      retval
    end
  end

  def query_subselect hts_number, country, join_table_name, join_table_with_id
    "(SELECT hts_#{hts_number} FROM classifications hts_#{hts_number}_class INNER JOIN tariff_records hts_#{hts_number}_tariff ON hts_#{hts_number}_tariff.classification_id = hts_#{hts_number}_class.id WHERE hts_#{hts_number}_class.country_id = #{country.id} AND hts_#{hts_number}_class.product_id = #{join_table_name}.#{join_table_with_id ? "id" : "product_id"} ORDER BY hts_#{hts_number}_tariff.line_number LIMIT 1)"
  end

  def make_country_hts_fields core_module, join_table_name: core_module.table_name, read_only: true, model_field_suffix: core_module.table_name, hts_numbers: 1..1, label_prefix: "Product - ", starting_index: nil, product_lambda:
    model_fields = []

    starting_index = starting_index.nil? ? next_index_number(core_module) : starting_index

    Country.import_locations.each do |c|
      hts_numbers.each_with_index do |i, x|
        field_name = "*fhts_#{i}_#{c.id}#{model_field_suffix.blank? ? "" : ("_" + model_field_suffix)}".to_sym
        mf = ModelField.new((starting_index + x), field_name, core_module, field_name,
          {label_override: "#{label_prefix}First HTS #{i} (#{c.iso_code})", data_type: :string, history_ignore: true, read_only: read_only,
            import_lambda: (read_only ? nil : import_lambda(product_lambda, i, c)),
            export_lambda: export_lambda(product_lambda, i, c), 
            qualified_field_name: query_subselect(i, c, join_table_name, core_module == CoreModule::PRODUCT),
            process_query_result_lambda: lambda {|r| r.nil? ? nil : r.hts_format }
          }
        )
        model_fields << mf
      end
    end
    model_fields
  end
end; end; end
