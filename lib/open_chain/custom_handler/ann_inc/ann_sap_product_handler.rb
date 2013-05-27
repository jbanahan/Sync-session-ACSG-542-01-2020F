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
              p.name = base_row[2].strip
              p.save!
              p.update_custom_value! @custom_definitions[:ac_date], earliest_ac_date(rows)
              p.update_custom_value! @custom_definitions[:prop_hts], base_row[9].strip
              p.update_custom_value! @custom_definitions[:prop_long], base_row[10].strip
              p.update_custom_value! @custom_definitions[:approved_long], base_row[10].strip
              p.update_custom_value! @custom_definitions[:imp_flag], (base_row[12].strip=='1')
              p.update_custom_value! @custom_definitions[:inco_terms], base_row[13].strip
              p.update_custom_value! @custom_definitions[:missy], base_row[14].strip
              p.update_custom_value! @custom_definitions[:petite], base_row[15].strip
              p.update_custom_value! @custom_definitions[:tall], base_row[16].strip
              p.update_custom_value! @custom_definitions[:season], base_row[17].strip
              p.update_custom_value! @custom_definitions[:article], base_row[18].strip
              f_sap = p.get_custom_value(@custom_definitions[:first_sap_date])
              if f_sap.value.nil?
                f_sap.value = 0.days.ago
                f_sap.save!
              end
              p.update_custom_value! @custom_definitions[:last_sap_date], 0.days.ago
              agg = aggregate_values rows
              [:po,:origin,:import,:cost,:dept_num,:dept_name].each {|s| write_aggregate_value agg, p, s}

              #don't fill values for the same import country twice
              used_countries = []
              rows.each do |row|
                iso = row[4].strip
                next if used_countries.include? iso
                used_countries << iso
                country = Country.find_by_iso_code_and_import_location iso, true
                next unless country #don't write classification for country that isn't setup or isn't an import location

                #build the classfiication
                cls = p.classifications.find_by_country_id country.id 
                cls = p.classifications.build(:country_id=>country.id) unless cls
                tr = cls.tariff_records.first
                tr = cls.tariff_records.build unless tr
                tr.hts_1 = row[9].gsub(/[^0-9]/,'') if tr.hts_1.blank? && hts_valid?(row[9],country)
                cls.save!

                cls.update_custom_value! @custom_definitions[:oga_flag], (row[11].strip=='1') 
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
            r[:po] << row[0].strip
            r[:origin] << row[3].strip
            r[:import] << row[4].strip
            r[:cost] << row[5].strip
            r[:dept_num] << row[7].strip
            r[:dept_name] << row[8].strip
          end
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
