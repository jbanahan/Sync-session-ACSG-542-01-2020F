require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
require 'open_chain/custom_handler/ann_inc/ann_related_styles_manager'
module OpenChain
  module CustomHandler
    module AnnInc
      class AnnSapProductHandler
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
        extend OpenChain::IntegrationClientParser

        SAP_REVISED_PRODUCT_FIELDS = [:origin,:import,:related_styles,:cost]
        def initialize
          @cdefs = self.class.prep_custom_definitions [:po,:origin,:import,:cost,
            :ac_date,:dept_num,:dept_name,:prop_hts,:prop_long,:oga_flag,:imp_flag,
            :inco_terms,:related_styles,:season,:article,:approved_long,
            :first_sap_date,:last_sap_date,:sap_revised_date, :minimum_cost, :maximum_cost
          ]
        end

        def self.parse file_content, opts = {}
          self.new.process file_content, User.find_by_username('integration')
        end

        def process file_content, run_by
          begin
            style_hash = {}
            # \007 turns the bell character into the quote char, which essentially turns off csv
            # quoting, but also enables the file to have "s in the file without turning on ruby's
            # csv quote handling and throwing errors.  Having | be the column separator and 
            # quote character causes issues when you try and test with a blank string as the column 
            # value.
            CSV.parse(file_content,{:quote_char=>"\007",:col_sep=>'|'}) do |row|
              next if row.blank? || row[1].blank?
              style = row[1].strip
              style_hash[style] ||= []
              style_hash[style] << row
            end
            style_hash.each do |style,rows|
              begin
                ActiveRecord::Base.transaction do
                  #using the first row as the basis for all non-aggregated values
                  base_row = rows.first
                  
                  related = extract_related_styles base_row
                  p = OpenChain::CustomHandler::AnnInc::AnnRelatedStylesManager.get_style(style,related[:missy],related[:petite],related[:tall])
                  
                  base_values = {} #values that could trigger the sap_revised date
                  update_sap_revised_date = false
                  SAP_REVISED_PRODUCT_FIELDS.each do |f| 
                    base_values[f] = p.get_custom_value(@cdefs[f]).value
                  end

                  p.name = clean_string(base_row[2])

                  p.save!


                  # Make sure we maintain the earliest AC date across any date values sent to us for any style (related styles or not)
                  write_earliest_ac_date rows, p.get_custom_value(@cdefs[:ac_date])

                  p.update_custom_value! @cdefs[:last_sap_date], Time.zone.now
                  p.update_custom_value! @cdefs[:prop_hts], clean_string(base_row[9])
                  p.update_custom_value! @cdefs[:prop_long], clean_string(base_row[10])
                  p.update_custom_value! @cdefs[:imp_flag], (clean_string(base_row[12])=='X')
                  p.update_custom_value! @cdefs[:inco_terms], clean_string(base_row[13])
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
                  
                  #don't fill values for the same import country twice
                  used_countries = []
                  rows.each do |row|
                    iso = clean_string(row[4])
                    next if used_countries.include? iso
                    used_countries << iso
                    country = get_country iso
                    next unless country #don't write classification for country that isn't setup or isn't an import location

                    #build the classfiication
                    hts = clean_string(row[9])
                    cls = get_or_create_classification p, country
                    # Classification may be nil if the iso code isn't enabled as an import country
                    if cls
                      oga_val = cls.get_custom_value(@cdefs[:oga_flag]).value

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
                  
                  end

                  agg = aggregate_values rows
                  [:po,:origin,:import,:cost,:dept_num,:dept_name].each {|s| write_aggregate_value agg, p, s, s==:cost, (s==:dept_name ? ", " : "\n")}
                  set_min_max_cost_values(p, agg[:min_max_per_country]) if agg[:min_max_per_country]

                  SAP_REVISED_PRODUCT_FIELDS.each do |f| 
                    update_sap_revised_date = true if base_values[f] != p.get_custom_value(@cdefs[f]).value
                  end
                  p.update_custom_value! @cdefs[:sap_revised_date], Time.zone.now if update_sap_revised_date
                  
                  p.create_snapshot run_by
                end
              rescue
                tmp = Tempfile.new(['AnnFileError','.csv'])
                rows.each {|r| tmp << r.to_csv}
                tmp.flush
                $!.log_me ["Error processing Ann Inc SAP rows.","NOTE: Original rows converted to CSV from pipe delimited."], [tmp.path]
                tmp.unlink
                raise $! unless Rails.env=='production'
              end
            end
          rescue
            tmp = Tempfile.new(['AnnFileError','.csv'])
            tmp << file_content
            tmp.flush
            $!.log_me ["Error processing Ann Inc SAP file"], [tmp.path]
            tmp.unlink
            raise $! unless Rails.env=='production'
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
        
        def write_aggregate_value aggregate_vals, product, symbol, reverse, delimiter
          # Append the aggregate values into the existing custom value
          vals = aggregate_vals[symbol]
          field = product.get_custom_value(@cdefs[symbol])
          if !field.value.blank?
            vals = field.value.split(delimiter) + vals
          end

          a_vals = vals.compact.uniq.sort
          a_vals.reverse! if reverse
          field.value = a_vals.join(delimiter)
          field.save!
        end
        
        def aggregate_values rows
          r = {:po=>[],:origin=>[],:import=>[],:cost=>[],:dept_num=>[],
            :dept_name=>[]}

          min_max_per_country = {}
          rows.each do |row|
            r[:po] << clean_string(row[0])
            r[:origin] << clean_string(row[3])
            import_country = clean_string(row[4])
            r[:import] << import_country
            min_max_per_country[import_country] ||= {:min=>nil, :max=>nil} unless import_country.blank?

            # There's probably some sprintf magic that could work here
            # to do this, but it escapes me.
            # Essentially, just make sure there's always at least 2 decimal places
            # and zero pad to at least 4 significant digits (at least 5 chars total with decimal point)
            cost_str = clean_string(row[5])
            unless cost_str.blank?
              cost = BigDecimal.new(cost_str) rescue nil
              unless cost.nil? || import_country.nil?
                if min_max_per_country[import_country][:min].nil? || min_max_per_country[import_country][:min] > cost
                  min_max_per_country[import_country][:min] = cost
                end

                if min_max_per_country[import_country][:max].nil? || min_max_per_country[import_country][:max] < cost
                  min_max_per_country[import_country][:max] = cost
                end
              end

              cost_parts = cost_str.split(".")
              cost_parts = ["0", "0"] if cost_parts.length == 0
              cost_parts << "0" if cost_parts.length == 1
              cost_parts[1] = cost_parts[1].ljust(2, "0")
              cost_str = cost_parts.join(".").rjust(5, "0")
              r[:cost] << clean_string("#{row[4]} - #{cost_str}")
            end

            r[:dept_num] << clean_string(row[7])
            r[:dept_name] << clean_string(row[8])
          end
          r.each {|k,v| v.uniq!}
          r[:min_max_per_country] = min_max_per_country if min_max_per_country.size > 0
          r
        end

        def write_earliest_ac_date rows, ac_date_field
          r = ac_date_field.value
          rows.each do |row|
            next if row[6].blank?
            ac_date = Date.strptime row[6], "%m/%d/%Y"
            r = ac_date if r.nil? || ac_date < r
          end
          
          ac_date_field.value = r
          ac_date_field.save!
        end

        def extract_related_styles base_row
          related_styles = {}
          related_styles[:missy] = clean_string(base_row[14]) unless base_row[14].blank?
          related_styles[:petite] = clean_string(base_row[15]) unless base_row[15].blank?
          related_styles[:tall] = clean_string(base_row[16]) unless base_row[16].blank?

          related_styles
        end

        def get_country iso
          # Only return valid import countries
          Country.import_locations.where(:iso_code => iso).first
        end

        def get_or_create_classification product, country
          if country.is_a? String
            #This should be the country ISO code
            country = get_country country
          end

          classification = nil
          if country
            # Find the classification that correlates to this country
            classification = product.classifications.find {|c| c.country_id == country.id}
            unless classification
              classification = product.classifications.create! country: country
            end
          end

          classification
        end

        def set_min_max_cost_values product, min_max_per_country
          min_max_per_country.each do |iso, min_max|
            next unless min_max[:min] || min_max[:max]

            classification = get_or_create_classification product, iso
           
            if classification
              if min_max[:min]
                field = classification.get_custom_value(@cdefs[:minimum_cost])
                if field.value.nil? || field.value > min_max[:min]
                  field.value = min_max[:min]
                  field.save!
                end
              end

              if min_max[:max]
                field = classification.get_custom_value(@cdefs[:maximum_cost])
                if field.value.nil? || field.value < min_max[:max]
                  field.value = min_max[:max]
                  field.save!
                end
              end
            end
          end
        end

      end
    end
  end
end
