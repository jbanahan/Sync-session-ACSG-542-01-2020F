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
              #using the first row as the basis for all non-aggregated values
              base_row = rows.first
              
              p, primary_product_data = nil, nil
              begin
                p, primary_product_data = find_existing_product(style, base_row)
              rescue 
                $!.log_me
                next
              end
              
              base_values = {} #values that could trigger the sap_revised date
              update_sap_revised_date = false
              if p
                SAP_REVISED_PRODUCT_FIELDS.each {|f| base_values[f] = p.get_custom_value(@cdefs[f]).value}
              else
                p = Product.new(:unique_identifier=>style) unless p
                primary_product_data = true
              end

              if primary_product_data
                p.name = clean_string(base_row[2])
                p.save!
              end

              # We want to set the missy, petite and tall values regardless of if we're pulling in data from 
              # a referenced related product or not. However, we don't want to null out existing related style values.
              update_related_style_value p, :missy, clean_string(base_row[14])
              update_related_style_value p, :petite, clean_string(base_row[15])
              update_related_style_value p, :tall, clean_string(base_row[16])
              
              if primary_product_data
                p.update_custom_value! @cdefs[:ac_date], earliest_ac_date(rows)
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
                p.update_custom_value! @cdefs[:last_sap_date], 0.days.ago

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
              end

              agg = aggregate_values rows
              [:po,:origin,:import,:cost,:dept_num,:dept_name].each {|s| write_aggregate_value agg, p, s, s==:cost, !primary_product_data}

              unless base_values.empty?
                SAP_REVISED_PRODUCT_FIELDS.each do |f| 
                  update_sap_revised_date = true if base_values[f] != p.get_custom_value(@cdefs[f]).value
                end
                p.update_custom_value! @cdefs[:sap_revised_date], Time.zone.now if update_sap_revised_date
              end
              
              p.create_snapshot run_by
            end
          rescue
            debugger
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
        
        def write_aggregate_value aggregate_vals, product, symbol, reverse, append_values
          vals = aggregate_vals[symbol]
          if append_values
            existing_val = product.get_custom_value(@cdefs[symbol]).value
            if !existing_val.blank?
              vals = existing_val.split("\n") + vals
            end
          end

          a_vals = vals.compact.sort
          a_vals.uniq! if append_values
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

        def extract_related_styles base_row
          related_styles = {}
          related_styles[:missy] = clean_string(base_row[14]) unless base_row[14].blank?
          related_styles[:petite] = clean_string(base_row[15]) unless base_row[15].blank?
          related_styles[:tall] = clean_string(base_row[16]) unless base_row[16].blank?

          related_styles
        end

        def set_missy_data product, row, style
          # The missy style (which we know we're processing here by virtue of there being a petite and tall related style value on this record)
          # is supposed to be the "master" product record.  So we switch the identifier to be this missy style and then process as 
          # we would a normal product record.
          product.unique_identifier = style
          product
        end

        def find_existing_product style, row
          related_styles = extract_related_styles row

          p = nil
          # This is basically a flag indicating that the current row we're parsing should be considered data for the primary style
          # as opposed to the related product records where we should only parse out the aggregate data from the file fields
          using_related_style = true
          if related_styles.include? :missy
            # Use the missy style's product record as the basis for this one if it exists.  We know that since we've referenced
            # a missy style in this record, that the record itself is NOT a missy style.
            p = Product.find_by_unique_identifier related_styles[:missy]

            if p.nil? && related_styles[:petite]
                p = Product.find_by_unique_identifier(related_styles[:petite])
            end

            if p.nil? && related_styles[:tall]
              p = Product.find_by_unique_identifier(related_styles[:tall])
            end

          elsif related_styles.include?(:petite) && related_styles.include?(:tall)
            # One of the petite or tall styles may already exist (both should not - if they do, this is an error)
            p = verify_found_products Product.find_all_by_unique_identifier(related_styles.values), {"Petite"=>related_styles[:petite], "Tall"=>related_styles[:tall]}
            if p
              p = set_missy_data p, row, style
              # While technically, this is a related style, since the missy data is the "master" we want it's data to be the primary data source
              # on the record.  So we parse all the row's fields instead of just the aggregated columns.
              using_related_style = false
            end
          elsif related_styles.size > 0
            # At this point, we know our record has either a petite or a tall related style.  Which means we possibly may have a missy style.
            related_style = related_styles[:tall].nil? ? related_styles[:petite] : related_styles[:tall]
            p = Product.find_by_unique_identifier related_style

            # If we found a single record, we'll update it
            if p && style == p.get_custom_value(@cdefs[:missy]).value
              # We can use the found record's data and see if our current record is referenced by it as a missy style.
              p = set_missy_data p, row, style
              using_related_style = false
            end
          end

          if p.nil?
            # So, every other lookup has failed, just use the style as a lookup
            p = Product.find_by_unique_identifier style
            using_related_style = false
          end

          [p, !using_related_style]
        end

        def verify_found_products result, styles
          if result.size > 1
            error = ""
            styles.each_pair{|k, v| error << "#{((error.size > 0) ? "and " : "")}#{k} style '#{v}'"}
            raise "Multiple related Ann Inc. product records found for " + error
          elsif result.size == 1
            result[0]
          else 
            nil
          end
        end 

        def update_related_style_value product, cd_type, value
          # This is an attempt to work around what I perceive is a bug in the custom field handling.
          # You get an error if you call model.get_custom_value for a custom value record that doesn't yet exist for a model
          # and then don't save the object and instead do something like call save on the model or try to create
          # a snapshot (like here).  You end up getting a DB error because something in active record ends up
          # attempting to double insert this new custom value record.  We could mitigate the issue by saving any new
          # custom value records that get_custom_value generates, but I don't want to add that now since that may cause all
          # sorts of other issues.
          related = product.get_custom_value @cdefs[cd_type]

          if !value.blank? || related.new_record?
            related.value = value
            related.save!
          end
        end

      end
    end
  end
end
