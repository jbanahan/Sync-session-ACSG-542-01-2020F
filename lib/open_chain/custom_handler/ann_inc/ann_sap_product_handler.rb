require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
module OpenChain
  module CustomHandler
    module AnnInc
      class AnnSapProductHandler
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport 
        SAP_REVISED_PRODUCT_FIELDS ||= [:origin,:import,:missy,:petite,:tall,:cost]
        def initialize
          @cdefs = prep_custom_definitions [:po,:origin,:import,:cost,
            :ac_date,:dept_num,:dept_name,:prop_hts,:prop_long,:oga_flag,:imp_flag,
            :inco_terms,:missy,:petite,:tall,:season,:article,:approved_long,
            :first_sap_date,:last_sap_date,:sap_revised_date
          ]
        end

        def process file_content, run_by
          begin
            style_hash = {}
            CSV.parse(file_content,{:quote_char=>'|',:col_sep=>'|'}) do |row|
              next if row.blank? || row[1].blank?
              style = row[1].strip
              style_hash[style] ||= []
              style_hash[style] << row
            end
            style_hash.each do |style,rows|
              p = Product.find_by_unique_identifier style
              base_values = {} #values that could trigger the sap_revised date
              update_sap_revised_date = false
              if p
                SAP_REVISED_PRODUCT_FIELDS.each {|f| base_values[f] = p.get_custom_value(@cdefs[f]).value}
              else
                p = Product.new(:unique_identifier=>style) unless p
              end

              #using the first row as the basis for all non-aggregated values
              base_row = rows.first
              p.name = clean_string(base_row[2])
              p.save!
              p.update_custom_value! @cdefs[:ac_date], earliest_ac_date(rows)
              p.update_custom_value! @cdefs[:prop_hts], clean_string(base_row[9])
              p.update_custom_value! @cdefs[:prop_long], clean_string(base_row[10])
              p.update_custom_value! @cdefs[:imp_flag], (clean_string(base_row[12])=='X')
              p.update_custom_value! @cdefs[:inco_terms], clean_string(base_row[13])
              p.update_custom_value! @cdefs[:missy], clean_string(base_row[14])
              p.update_custom_value! @cdefs[:petite], clean_string(base_row[15])
              p.update_custom_value! @cdefs[:tall], clean_string(base_row[16])
              p.update_custom_value! @cdefs[:season], clean_string(base_row[17])
              p.update_custom_value! @cdefs[:article], clean_string(base_row[18])
              f_sap = p.get_custom_value(@cdefs[:first_sap_date])
              if f_sap.value.nil?
                f_sap.value = 0.days.ago
                f_sap.save!
              end
              approved_long = p.get_custom_value(@cdefs[:approved_long])
              if approved_long.value.blank?
                approved_long.value = clean_string(base_row[10])
                approved_long.save!
              end
              p.update_custom_value! @cdefs[:last_sap_date], 0.days.ago
              agg = aggregate_values rows
              [:po,:origin,:import,:cost,:dept_num,:dept_name].each {|s| write_aggregate_value agg, p, s, s==:cost}

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
                oga_val = nil
                if cls
                  oga_val = cls.get_custom_value(@cdefs[:oga_flag]).value
                else
                  cls = p.classifications.build(:country_id=>country.id) unless cls
                end
                unless hts.blank?
                  tr = cls.tariff_records.first
                  tr = cls.tariff_records.build unless tr
                  tr.hts_1 = hts.gsub(/[^0-9]/,'') if tr.hts_1.blank? && hts_valid?(row[9],country)
                end
                cls.save!
                
                new_oga_value = (clean_string(row[11])=='X')
                cls.update_custom_value! @cdefs[:oga_flag], new_oga_value
                if !oga_val.nil?
                  update_sap_revised_date = true if oga_val!=new_oga_value
                end
              end

              unless base_values.empty?
                SAP_REVISED_PRODUCT_FIELDS.each do |f| 
                  update_sap_revised_date = true if base_values[f] != p.get_custom_value(@cdefs[f]).value
                end
                p.update_custom_value! @cdefs[:sap_revised_date], Time.zone.now if update_sap_revised_date
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
        def write_aggregate_value aggregate_vals, product, symbol, reverse
          a_vals = aggregate_vals[symbol].compact.sort
          a_vals.reverse! if reverse
          product.update_custom_value! @cdefs[symbol], a_vals.join("\n")
        end
        def aggregate_values rows
          r = {:po=>[],:origin=>[],:import=>[],:cost=>[],:dept_num=>[],
            :dept_name=>[]}
          rows.each do |row|
            r[:po] << clean_string(row[0])
            r[:origin] << clean_string(row[3])
            r[:import] << clean_string(row[4])
            cost_str = row[5]
            while cost_str.length < 5
              cost_str = "0#{cost_str}"
            end
            r[:cost] << clean_string("#{row[4]} - #{cost_str}")
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
