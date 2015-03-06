module OpenChain; module ModelFieldGenerator; module CountryHtsGenerator
  def make_country_hts_fields
    model_fields = []
    Country.import_locations.each do |c|
      (1..3).each do |i|
        mf = ModelField.new(next_index_number(CoreModule::PRODUCT),
          "*fhts_#{i}_#{c.id}".to_sym,
          CoreModule::PRODUCT,
          "*fhts_#{i}_#{c.id}".to_sym,
          {:label_override => "First HTS #{i} (#{c.iso_code})",
            :data_type=>:string,
            :history_ignore=>true,
            :import_lambda => lambda {|p,d|
              #validate HTS
              hts = TariffRecord.clean_hts(d)
              return "Blank HTS ignored for #{c.iso_code}" if hts.blank?
              unless OfficialTariff.find_by_country_id_and_hts_code(c.id,hts) || OfficialTariff.where(country_id:c.id).empty?
                e = "#{d} is not valid for #{c.iso_code} HTS #{i}"
                # Indicate the message is an error message
                def e.error?; true; end
                return e;
              end
              cls = nil
              #find classifications & tariff records in memory so this can work on objects that are dirty
              p.classifications.each do |existing|
                cls = existing if existing.country_id == c.id
                break if cls
              end
              cls = p.classifications.build(:country_id=>c.id) unless cls
              tr = nil
              tr = cls.tariff_records.sort {|a,b| a.line_number <=> b.line_number}.first
              tr = cls.tariff_records.build unless tr
              tr.send("hts_#{i}=".intern,hts)
              "#{c.iso_code} HTS #{i} set to #{hts.hts_format}"
            },
            :export_lambda => lambda {|p|
              #do this in memory with a loop over classifications instead of a where
              #since there is a better probability that classifications will already be loaded
              #and we don't want to hit the database again
              cls = nil
              p.classifications.each do |cl|
                cls = cl if cl.country_id == c.id
                break if cls
              end
              return "" unless cls && cls.tariff_records.first
              h = cls.tariff_records.first.send "hts_#{i}"
              h.nil? ? "" : h.hts_format
            },
            :qualified_field_name => "(SELECT hts_#{i} FROM tariff_records INNER JOIN classifications ON tariff_records.classification_id = classifications.id WHERE classifications.country_id = #{c.id} AND classifications.product_id = products.id ORDER BY tariff_records.line_number LIMIT 1)",
            :process_query_result_lambda => lambda {|r| r.nil? ? nil : r.hts_format }
          }
        )
        model_fields << mf
      end
    end
    model_fields
  end
end; end; end
