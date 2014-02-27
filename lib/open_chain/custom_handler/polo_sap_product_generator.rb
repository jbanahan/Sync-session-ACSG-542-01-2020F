require 'open_chain/custom_handler/product_generator'
module OpenChain
  module CustomHandler
    class PoloSapProductGenerator < ProductGenerator

      #SchedulableJob compatibility
      def self.run_schedulable opts={}
        g = self.new(opts)
        g.ftp_file g.sync_csv
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
        raise "SAP Brand custom definition does not exist." unless @sap_brand
      end

      def sync_code 
        'polo_sap'
      end

      def ftp_credentials
        {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>"to_ecs/Ralph_Lauren/sap_#{@env==:qa ? 'qa' : 'prod'}"}
      end

      def preprocess_row row
        row.each do |key, val|
          row[key] = convert_to_ascii(val)
        end

        [row]
      rescue ArgumentError, Encoding::UndefinedConversionError => e
        # In cases of errors, we're just sending out error emails to ourselves at this point since
        # we don't really think we'll encounter this very often.

        # The product generator trims off the id, so the first value in the row is the unique_identifier.
        e.log_me ["Invalid character data found in product with unique_identifier '#{row[0]}'."]
        return nil
      end

      def convert_to_ascii value
        if value && value.is_a?(String)
          allowed_conversions = {
            "\u{00A0}" => " ", #non breaking space
            "\u{2013}" => "-",
            "\u{2014}" => "-",
            "\u{00BE}" => "3/4",
            "\u{201D}" => "\"", # Right quote-mark ”
            "\u{201C}" => "\"" # Left quote-mark “
          }
          # First convert the UTF-8 text to ascii w/ our conversion table
          value = value.encode("US-ASCII", :fallback => allowed_conversions)

          # Convert tab chars to spaces
          value = value.gsub("\t", " ")

          # Now fail if there are any non-printing chars (aside from newlines ASCII 10 && 13)
          # ie. ASCII chars < 32 or > 126.  (Extended ASCII range is not allowed - it shouldn't even get translated in the encode call anyway.)
          # I'm sure there's a way to write a regular expression using ascii codepoints, but I'm not seeing
          # it, so I'm just going to loop the characters and check them all manually.
          value.each_codepoint do |code|
            if (code < 32 || code > 126) && ![10, 13].include?(code)
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

      def query
        q = "SELECT products.id,
products.unique_identifier, 
#{cd_s 6},
(select iso_code from countries where countries.id = classifications.country_id) as 'Classification - Country ISO Code',
tariff_records.hts_1 as 'Tariff - HTS Code 1',
#{cd_s 130},
#{cd_s 22},
#{cd_s 7},
#{cd_s 79},
#{cd_s 78},
#{cd_s 131},
#{cd_s 142},
#{cd_s 143},
#{cd_s 144},
#{cd_s 145},
#{cd_s 146},
#{cd_s 147},
#{cd_s 148},
#{cd_s 149},
#{cd_s 150},
#{cd_s 151},
#{cd_s 132},
#{cd_s 133},
#{cd_s 134},
#{cd_s 135},
#{cd_s 136},
#{cd_s 137},
#{cd_s 138},
#{cd_s 139},
#{cd_s 140},
#{cd_s 141}
FROM products 
#{@no_brand_restriction ? "" : "INNER JOIN custom_values sap_brand ON sap_brand.custom_definition_id = #{@sap_brand.id} AND sap_brand.customizable_id = products.id AND sap_brand.boolean_value = 1" }
INNER JOIN classifications on classifications.product_id = products.id AND classifications.country_id IN (SELECT id FROM countries WHERE iso_code IN ('IT','US','CA'))
INNER JOIN tariff_records on tariff_records.classification_id = classifications.id and length(tariff_records.hts_1) > 0
#{Product.need_sync_join_clause(sync_code)} "
        w = "WHERE #{Product.need_sync_where_clause()}"
        q << (@custom_where ? @custom_where : w)
        q
      end
    end
  end
end
