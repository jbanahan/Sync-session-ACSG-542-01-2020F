require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
module OpenChain
  module CustomHandler
    module AnnInc
      class AnnSapProductHandler
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport 
        def initialize
          @custom_definitions = prep_custom_definitions [:po,:origin,:import,:cost,
            :ac_date,:dept_num,:dept_name,:prop_hts,:prop_long,:oga_flag,:imp_flag,
            :inco_terms,:missy,:petite,:tall,:season,:article,:approved_long,:approved_date,
            :first_sap_date,:last_sap_date
          ]
        end

        def process file_content, run_by
          begin
            style_hash = {}
            CSV.parse(file_content,:col_sep=>'|') do |row|
              style = row[1].strip
              style_hash[style] ||= []
              style_hash[style] << row
            end
            style_hash.each do |style,rows|
              p = Product.find_by_unique_identifier style
              p = Product.new(:unique_identifier=>style) unless p

              #using the first row as the basis for all non-aggregated values
              base_row = rows.first
              p.name = clean_string(base_row[2])
              p.save!
              p.update_custom_value! @custom_definitions[:ac_date], earliest_ac_date(rows)
              p.update_custom_value! @custom_definitions[:prop_hts], clean_string(base_row[9])
              p.update_custom_value! @custom_definitions[:prop_long], clean_string(base_row[10])
              p.update_custom_value! @custom_definitions[:imp_flag], (clean_string(base_row[12])=='X')
              p.update_custom_value! @custom_definitions[:inco_terms], clean_string(base_row[13])
              p.update_custom_value! @custom_definitions[:missy], clean_string(base_row[14])
              p.update_custom_value! @custom_definitions[:petite], clean_string(base_row[15])
              p.update_custom_value! @custom_definitions[:tall], clean_string(base_row[16])
              p.update_custom_value! @custom_definitions[:season], clean_string(base_row[17])
              p.update_custom_value! @custom_definitions[:article], clean_string(base_row[18])
              f_sap = p.get_custom_value(@custom_definitions[:first_sap_date])
              if f_sap.value.nil?
                f_sap.value = 0.days.ago
                f_sap.save!
              end
              approved_long = p.get_custom_value(@custom_definitions[:approved_long])
              if approved_long.value.blank?
                approved_long.value = clean_string(base_row[10])
                approved_long.save!
              end
              p.update_custom_value! @custom_definitions[:last_sap_date], 0.days.ago
              agg = aggregate_values rows
              [:po,:origin,:import,:cost,:dept_num,:dept_name].each {|s| write_aggregate_value agg, p, s}

              #don't fill values for the same import country twice
              used_countries = []
              rows.each do |row|
                iso = clean_string(row[4])
                next if used_countries.include? iso
                used_countries << iso
                country = Country.find_by_iso_code_and_import_location iso, true
                next unless country #don't write classification for country that isn't setup or isn't an import location

                #build the classfiication
                hts = clean_string(row[9])
                cls = p.classifications.find_by_country_id country.id 
                cls = p.classifications.build(:country_id=>country.id) unless cls
                unless hts.blank?
                  tr = cls.tariff_records.first
                  tr = cls.tariff_records.build unless tr
                  tr.hts_1 = hts.gsub(/[^0-9]/,'') if tr.hts_1.blank? && hts_valid?(row[9],country)
                end
                cls.save!

                cls.update_custom_value! @custom_definitions[:oga_flag], (clean_string(row[11])=='X') 
              end
              p.create_snapshot run_by
            end
          rescue
            tmp = Tempfile.new(['AnnFileError','.csv'])
            tmp << file_content
            tmp.flush
            $!.log_me ["Error processing Ann Inc SAP file"], [tmp.path]
            raise $! unless Rails.env=='production'
            tmp.unlink
          end
        end
        private
        def clean_string x
          return nil if x.blank?
          x.strip
        end
        def hts_valid? hts_number, country
          !country.official_tariffs.find_by_hts_code(hts_number.gsub(/[^0-9]/,'')).blank?
        end
        def write_aggregate_value aggregate_vals, product, symbol
          product.update_custom_value! @custom_definitions[symbol], aggregate_vals[symbol].compact.join("\n")
        end
        def aggregate_values rows
          r = {:po=>[],:origin=>[],:import=>[],:cost=>[],:dept_num=>[],
            :dept_name=>[]}
          rows.each do |row|
            r[:po] << clean_string(row[0])
            r[:origin] << clean_string(row[3])
            r[:import] << clean_string(row[4])
            r[:cost] << clean_string(row[5])
            r[:dept_num] << clean_string(row[7])
            r[:dept_name] << clean_string(row[8])
          end
          r.each {|k,v| v.uniq!}
          r
        end
        def earliest_ac_date rows
          r = nil
          rows.each do |row|
            next if row[6].blank?
            ac_date = Date.strptime row[6], "%m/%d/%Y"
            r = ac_date if r.nil? || ac_date < r
          end
          r
        end
      end
    end
  end
end
