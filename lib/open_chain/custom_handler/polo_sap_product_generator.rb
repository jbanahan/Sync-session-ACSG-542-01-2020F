require 'open_chain/custom_handler/product_generator'
require 'open_chain/xml_builder'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain
  module CustomHandler
    class PoloSapProductGenerator < ProductGenerator
      include OpenChain::XmlBuilder
      include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

      #SchedulableJob compatibility
      def self.run_schedulable opts={}
        g = self.new(opts)
        f = nil
        begin
          # Sync only does 500 products at a time now, so keep running the send
          # until we get a file output w/ zero lines (sync_xml returns a nil file in this case)
          f = g.sync_xml
          g.ftp_file f unless f.nil?
        end while !f.nil?
      end

      #Accepts 3 parameters
      # * :env=>:qa to send to qa ftp folder
      # * :custom_where to replace the query where clause
      # * :no_brand_restriction to allow styles to be sent that don't have SAP Brand set
      def initialize params = {}
        @env = params[:env]
        @custom_where = params[:custom_where]
        @sap_brand = CustomDefinition.find_by_module_type_and_label('Product','SAP Brand')
        @no_brand_restriction = params[:no_brand_restriction]
        @custom_countries = params[:custom_countries]
        raise "SAP Brand custom definition does not exist." unless @sap_brand
      end

      def sync_code
        'polo_sap'
      end

      def ftp_credentials
        folder = "to_ecs/ralph_lauren/sap_" + ((@env == :qa) ? "qa" : 'prod')
        connect_vfitrack_net folder
      end

      def sync
        @previous_style = nil
        @previous_iso = nil
        super
      end

      def sync_xml
        f = Tempfile.new(['ProductSync-','.xml'])
        cursor = 0
        xml, root = nil

        sync do |rv|
          if xml.nil?
            xml, root = build_xml_document("products", suppress_xml_declaration: true)
          end

          # I'm just going to keep the semantics of the csv sync, even though we're doing an xml file now, it's less code-rewriting
          # and the csv concept overlays w/ the sql row results more closely.
          max_col = rv.keys.sort.last
          # Turn blank / nil values into spaces
          row = (0..max_col).map {|i| rv[i].blank? ? "" : rv[i]}
          row = before_csv_write cursor, row
          write_row_to_xml root, row

          cursor += 1
        end
        if cursor > 0
          f << xml.to_s
          f.flush
          f.rewind
          return f
        else
          f.close!
          return nil
        end
      end

      def write_row_to_xml parent_element, row
        # Since we're mimic'ing the to_csv values we used to send, by default, to_csv just does a String(val) to convert values to string, so we're doing the same
        row = row.map {|s| String(s) }

        prod = add_element parent_element, "product"
        add_element prod, "style", row[0]
        add_element prod, "long_description", row[6]
        add_element prod, "fiber_content", row[34].present? ? row[34] : row[1]
        add_element prod, "down_indicator", row[5]
        add_element prod, "country_of_origin", row[8]
        add_element prod, "hts", row[3]
        add_element prod, "cites", row[4]
        add_element prod, "classification_country", row[2]
        add_element prod, "fish_and_wildlife", row[7]
        add_element prod, "genus_1", row[20]
        add_element prod, "species_1", row[25]
        add_element prod, "cites_origin_1", row[10]
        add_element prod, "cites_source_1", row[15]
        add_element prod, "genus_2", row[21]
        add_element prod, "species_2", row[26]
        add_element prod, "cites_origin_2", row[11]
        add_element prod, "cites_source_2", row[16]
        add_element prod, "genus_3", row[22]
        add_element prod, "species_3", row[27]
        add_element prod, "cites_origin_3", row[12]
        add_element prod, "cites_source_3", row[17]
        add_element prod, "genus_4", row[23]
        add_element prod, "species_4", row[28]
        add_element prod, "cites_origin_4", row[13]
        add_element prod, "cites_source_4", row[18]
        add_element prod, "genus_5", row[24]
        add_element prod, "species_5", row[29]
        add_element prod, "cites_origin_5", row[14]
        add_element prod, "cites_source_5", row[19]
        add_element prod, "stitch_count_2cm_vertical", "", allow_blank: true
        add_element prod, "stitch_count_2cm_horizontal", "", allow_blank: true
        add_element prod, "allocation_category", row[32]
        knit_woven = row[33]
        if !knit_woven.blank?
          if knit_woven.upcase == "KNIT"
            knit_woven = "KNT"
          elsif knit_woven.upcase == "WOVEN"
            knit_woven = "WVN"
          else
            knit_woven = ""
          end
        end
        add_element prod, "knit_woven", knit_woven
        add_element prod, "fda", row[35]
        add_element prod, "set", row[9]
      end

      def preprocess_header_row row, opts = {}
        # Skip the header row, don't need it coming back down through into the handler for the sync rows
        nil
      end

      def preprocess_row row, opts = {}
        # We need to prevent sending multiple tariff lines for the same product (.ie only send a single line for sets).
        # The query results are ordered so that we can just skip any styles/country iso that we've seen immediately prior to this one.
        # So, just track the previous style/iso and if it matches the previous...skip it.
        result = nil
        current_style = nil
        current_iso = nil
        begin
          converted = {}
          row.each do |key, val|
            converted[key] = convert_to_ascii(val)
          end

          current_style = converted[0]
          current_iso = converted[2]

          if @previous_style != current_style || @previous_iso != current_iso
            result = [converted]
          end
        rescue ArgumentError, Encoding::UndefinedConversionError => e
          # In cases of errors, we're just sending out error emails to ourselves at this point since
          # we don't really think we'll encounter this very often.

          # The product generator trims off the id, so the first value in the row is the unique_identifier.
          e.log_me ["Invalid character data found in product with unique_identifier '#{row[0]}'."]
        end

        @previous_style = current_style
        @previous_iso = current_iso
        result
      end

      def convert_to_ascii value
        if value && value.is_a?(String)
          allowed_conversions = {
              "\u{00A0}" => " ", #non breaking space
              "\u{2013}" => "-",
              "\u{2014}" => "-",
              "\u{00BE}" => "3/4",
              "\u{201D}" => "\"", # Right quote-mark ”
              "\u{201C}" => "\"", # Left quote-mark “
              "\u{00BC}" => "1/4",
              "\u{00BD}" => "1/2",
              "\u{00FA}" => "u", #u w/ acute http://www.fileformat.info/info/unicode/char/fa/index.htm
              "\u{00AE}" => "", # blank out registered character
              "\u{2019}" => "'" # Right single quote-mark '
          }
          # First convert the UTF-8 text to ascii w/ our conversion table
          value = value.encode("US-ASCII", :fallback => allowed_conversions)

          # Convert tab chars and "forbidden" characters to spaces
          value = value.gsub(/[<>^&{}\[\]+|*~;\t?]/, " ")

          # Now fail if there are any non-printing chars
          # ie. ASCII chars < 32 or > 126.  (Extended ASCII range is not allowed - it shouldn't even get translated in the encode call anyway.)
          # I'm sure there's a way to write a regular expression using ascii codepoints, but I'm not seeing
          # it, so I'm just going to loop the characters and check them all manually.
          value.each_codepoint do |code|
            # Carriage Return / Line Feeds are stripped later
            if (code != 10 && code != 13 && (code < 32 || code > 126))
              raise ArgumentError, "Non-printing ASCII code '#{code}' found in the value #{value}."
            end
          end

        end

        value
      end

      def before_csv_write cursor, vals
        vals[3] = vals[3].hts_format
        vals[8] = vals[8].length==2 ? vals[8].upcase : "" unless vals[8].blank?
        clean_string_values vals, true #true = remove quotes
        vals
      end

      def max_products
        500
      end

      def query
        @cdefs ||= self.class.prep_custom_definitions self.class.cdefs

        <<-SQL 
          SELECT products.id,
            products.unique_identifier,
            #{cd_s @cdefs[:fiber_content]},
            countries.iso_code AS 'Classification - Country ISO Code',
            tariff_records.hts_1 AS 'Tariff - HTS Code 1',
            #{custom_def_query_fields}
          FROM products
            #{@no_brand_restriction ? "" : "INNER JOIN custom_values sap_brand ON sap_brand.custom_definition_id = #{@sap_brand.id} AND sap_brand.customizable_id = products.id AND sap_brand.boolean_value = 1" }
            INNER JOIN classifications ON classifications.product_id = products.id
            INNER JOIN countries ON classifications.country_id = countries.id AND countries.iso_code IN (
            #{@custom_countries.blank? ? "'IT','US','CA','KR','JP','HK', 'NO'" : @custom_countries.collect { |c| "'#{c}'" }.join(',')}
              )
            INNER JOIN tariff_records ON tariff_records.classification_id = classifications.id AND LENGTH(tariff_records.hts_1) > 0
            INNER JOIN (#{inner_query}) inner_query ON inner_query.id = products.id
          ORDER BY products.updated_at, products.unique_identifier, countries.iso_code, tariff_records.line_number
        SQL
      end

      def inner_query
        q = <<-SQL
              SELECT DISTINCT products.id
              FROM products
                #{@no_brand_restriction ? "" : "INNER JOIN custom_values sap_brand ON sap_brand.custom_definition_id = #{@sap_brand.id} AND sap_brand.customizable_id = products.id AND sap_brand.boolean_value = 1" }
                INNER JOIN classifications ON classifications.product_id = products.id 
                INNER JOIN countries ON classifications.country_id = countries.id AND countries.iso_code IN (
                #{@custom_countries.blank? ? "'IT','US','CA','KR','JP','HK', 'NO'" : @custom_countries.collect { |c| "'#{c}'" }.join(',')})
                INNER JOIN tariff_records ON tariff_records.classification_id = classifications.id AND LENGTH(tariff_records.hts_1) > 0
                LEFT OUTER JOIN custom_values ax_export_manual ON ax_export_manual.customizable_id = products.id AND ax_export_manual.customizable_type = 'Product' AND ax_export_manual.custom_definition_id = #{@cdefs[:ax_export_status_manual].id}
            SQL
        
        if @custom_where.blank?
          q << " #{Product.need_sync_join_clause(sync_code)} "
          q << " WHERE #{Product.need_sync_where_clause()} AND !(ax_export_manual.string_value <=> 'EXPORTED') "
        else
          q << " #{@custom_where} "
        end

        q << " ORDER BY products.updated_at ASC LIMIT #{max_products}"
        q
      end

      def self.cdefs
        [:fiber_content, :cites, :meets_down_requirments, :long_description, :fish_wildlife, :country_of_origin, :set_type,
         :fish_wildlife_origin_1, :fish_wildlife_origin_2, :fish_wildlife_origin_3, :fish_wildlife_origin_4, :fish_wildlife_origin_5,
         :fish_wildlife_source_1, :fish_wildlife_source_2, :fish_wildlife_source_3, :fish_wildlife_source_4, :fish_wildlife_source_5,
         :common_name_1, :common_name_2, :common_name_3, :common_name_4, :common_name_5, :scientific_name_1, :scientific_name_2, 
         :scientific_name_3, :scientific_name_4, :scientific_name_5, :stitch_count_vertical, :stitch_count_horizontal, :allocation_category, 
         :knit_woven, :clean_fiber_content, :prod_fda_indicator, :ax_export_status_manual]
      end

      def custom_def_query_fields
        fields = []
        self.class.cdefs.each do |cdef|
          next if cdef == :fiber_content # Fiber content is handled directly in the query, so skip here

          if [:cites, :fish_wildlife, :meets_down_requirments].include? cdef
            fields << cd_s(@cdefs[cdef], boolean_y_n: true)
          elsif cdef == :long_description
            fields << cd_s(@cdefs[cdef], suppress_data: true)
          else
            fields << cd_s(@cdefs[cdef])
          end
        end

        fields.join(",\n")
      end
    end
  end
end
