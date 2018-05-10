require 'open_chain/integration_client_parser'
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
            :ac_date,:ordln_ac_date,:ord_ac_date,:dept_num,:dept_name,:prop_hts,:prop_long,:oga_flag,:imp_flag,
            :inco_terms,:related_styles,:season,:article,:approved_long,
            :first_sap_date,:last_sap_date,:sap_revised_date, :minimum_cost, :maximum_cost, :mp_type,
            :ord_docs_required, :ordln_import_country,:dsp_effective_date,:dsp_type,:ord_type,:ord_cancelled
          ]
        end

        def self.parse file_content, opts = {}
          self.new.process file_content, User.find_by_username('integration'), opts
        end

        def process file_content, run_by, opts
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
            # The following custom feature is here pretty much solely to be able to reprocess just orders or just Products
            generate_products(style_hash, run_by) unless MasterSetup.get.custom_feature?("Ann Skip SAP Product Parsing")
            generate_orders(style_hash, run_by, opts) unless MasterSetup.get.custom_feature?("Ann Skip SAP Order Parsing")
          rescue
            tmp = Tempfile.new(['AnnFileError','.csv'])
            tmp << file_content
            tmp.flush
            $!.log_me ["Error processing Ann Inc SAP file"], [tmp.path]
            tmp.unlink
            raise $! unless Rails.env=='production'
          end
        end

        def not_order?(row)
          row[0].match(/45\d{8}/)
        end

        def find_vendors row, master_company, dsp_type, opts
          vendor = nil
          selling_agent = nil
          buying_agent = nil

          vendor = find_or_create_vendor row[20], row[21], master_company, dsp_type, opts

          unless row[23].blank? || row[24].blank?
            selling_agent = find_or_create_vendor row[23], row[24], master_company, dsp_type, opts
            selling_agent[:company].update_attribute(:selling_agent, true)
          end
          buying_agent = find_or_create_vendor row[25], row[26], master_company, dsp_type, opts unless row[25].blank? || row[26].blank?

          [vendor, selling_agent, buying_agent]
        end

        def send_new_company_email vendor, order
          subject = "[VFI Track] New Party #{vendor.name} created in system"
          body = "This new party #{vendor.name} with SAP ID #{vendor.system_code} has been created in the system from order #{order.order_number}. Please set up users if necessary."
          OpenMailer.send_simple_html(['ann-support@vandegriftinc.com',
                                      'Elizabeth_Hodur@anninc.com',
                                      'Veronica_Miller@anninc.com',
                                      'alyssa_ahmed@anninc.com'], subject, body).deliver!
        end

        def order_being_cancelled?(row)
          line = row.dup
          [0, 1, 2, 14, 15, 16, 22].each do |i|
            line[i] = nil
          end
          line.compact!
          line.empty?
        end

        def cancel_order(order_number)
          order = Order.where(order_number: order_number).first
          if order
            order.find_and_set_custom_value(@cdefs[:ord_cancelled], true)
            order.save!
          end
        end

        def generate_orders(style_hash, run_by, opts)
          master_company = Company.where(master: true).first
          style_hash.each do |style, rows|
            rows.each do |row|
              next if not_order?(row)

              dsp_type = row[19]
              if dsp_type.present? && dsp_type.include?('Standard')
                dsp_type = dsp_type.gsub('Standard PO', 'Standard')
              end

              if order_being_cancelled?(row)
                cancel_order(row[0])
              else
                vendor, selling_agent, buying_agent = find_vendors row, master_company, dsp_type, opts

                find_order(row[0], master_company, vendor) do |o|
                  [vendor, buying_agent, selling_agent].each do |co|
                    next if co.blank?
                    send_new_company_email(co[:company], o) if co[:new_record] && co[:company].get_custom_value(@cdefs[:dsp_type]).value == "MP"
                  end

                  base_row = rows.first
                  related = extract_related_styles base_row
                  p = OpenChain::CustomHandler::AnnInc::AnnRelatedStylesManager.get_style(base_style: style, missy: related[:missy], petite: related[:petite], tall: related[:tall], short: related[:short], plus: related[:plus])
                  o.terms_of_sale = row[13]
                  o.agent = buying_agent[:company] if buying_agent.present?
                  o.selling_agent = selling_agent[:company] if selling_agent.present?
                  o.find_and_set_custom_value(@cdefs[:ord_type], row[19])
                  ol = o.order_lines.find { |ol| ol.product.unique_identifier == p.unique_identifier }
                  ol = o.order_lines.build product: p if ol.blank?
                  ol.country_of_origin = row[3]
                  ol.price_per_unit = row[5]
                  ol.hts = row[9]
                  ol.quantity = row[22]
                  ol.find_and_set_custom_value(@cdefs[:ordln_import_country], row[4])
                  ol.find_and_set_custom_value(@cdefs[:ordln_ac_date], parsed_date(row[6]))
                  ship_window_start = parsed_date(row[6])
                  o.ship_window_start = ship_window_start
                  o.find_and_set_custom_value(@cdefs[:ord_docs_required], docs_required?(vendor, row, ship_window_start)) 
                  ol.save!
                  o.save!
                  o.create_snapshot run_by
                end
              end
            end
          end
        end

        def docs_required?(vendor, row, ship_window_start)
          # Docs are never required unless the PO order type is MP
          return false if row[19] != 'MP'

          # If order type is MP, then docs are required IFF Vendor's MP Type is 'All Docs'  && the Order's Ship window start is on 
          # or after Vendor's effective date
          if vendor[:company].custom_value(@cdefs[:mp_type]) == "All Docs"
            effective_date = vendor[:company].custom_value(@cdefs[:dsp_effective_date])

            return !effective_date.nil? && !ship_window_start.nil? && ship_window_start.to_date >= effective_date
          end

          return false
        end

        def parsed_date(date_string)
          return nil unless date_string.present?
          m, d, y = date_string.split('/')
          Time.zone.parse("#{d}/#{m}/#{y}")
        end

        def find_or_create_vendor system_code, name, master_company, dsp_type, opts
          if system_code.present? && name.present?
            co = nil
            new_record = false
            Lock.acquire("Company-#{system_code}") do 
              co = Company.where(system_code: system_code).first_or_initialize(vendor: true, name: name)
              new_record = co.new_record?

              if new_record
                co.find_and_set_custom_value(@cdefs[:dsp_type], dsp_type)
                co.find_and_set_custom_value(@cdefs[:mp_type], 'Not Participating') if ['Standard', 'AP'].include?(dsp_type)
                co.show_business_rules = true
                co.save!
              elsif co.name != name
                co.name = name
                co.save!
              end

              master_company.linked_companies << co if new_record

              co.create_snapshot(User.integration, nil, opts[:key]) if new_record
            end
            {company: co, new_record: new_record}
          else
            {company: nil, new_record: false}
          end

        end

        def find_order order_number, importer, vendor
          o = nil
          Lock.acquire("ANN-#{order_number}") do
            po = Order.where(order_number: order_number).first_or_create! vendor: vendor[:company], importer: importer
            po.customer_order_number = order_number

            Lock.with_lock_retry(po) do
              o = yield po
            end
          end
        end

        def generate_products(style_hash, run_by)
          style_hash.each do |style,rows|
            begin
              ActiveRecord::Base.transaction do
                #using the first row as the basis for all non-aggregated values
                base_row = rows.first

                related = extract_related_styles base_row
                p = OpenChain::CustomHandler::AnnInc::AnnRelatedStylesManager.get_style(base_style: style, missy: related[:missy], petite: related[:petite], tall: related[:tall], short: related[:short], plus: related[:plus])

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
                p.update_attributes! last_updated_by: run_by
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
          related_styles[:short] = clean_string(base_row[27]) unless base_row[27].blank?
          related_styles[:plus] = clean_string(base_row[28]) unless base_row[28].blank?

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
