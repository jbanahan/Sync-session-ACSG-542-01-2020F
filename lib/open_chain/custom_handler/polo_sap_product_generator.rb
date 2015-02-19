require 'open_chain/custom_handler/product_generator'
module OpenChain
  module CustomHandler
    class PoloSapProductGenerator < ProductGenerator

      #SchedulableJob compatibility
      def self.run_schedulable opts={}
        g = self.new(opts)
        f = nil
        begin
          # Sync only does 500 products at a time now, so keep running the send 
          # until we get a file output w/ zero lines (sync_csv returns a nil file in this case, 
          # it's also smart enough not to send a file w/ only headers in it)
          f = g.sync_csv
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
        {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>"to_ecs/Ralph_Lauren/sap_#{@env==:qa ? 'qa' : 'prod'}"}
      end

      def preprocess_row row, opts = {}
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
        q = "SELECT products.id,
products.unique_identifier, 
#{cd_s 6},
(select iso_code from countries where countries.id = classifications.country_id) as 'Classification - Country ISO Code',
tariff_records.hts_1 as 'Tariff - HTS Code 1',
#{cd_s 130},
#{cd_s 22},
#{cd_s 7, suppress_data: true},
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
INNER JOIN classifications on classifications.product_id = products.id AND classifications.country_id IN (SELECT id FROM countries WHERE iso_code IN (
#{@custom_countries.blank? ? "'IT','US','CA','KR','JP','HK'" : @custom_countries.collect { |c| "'#{c}'" }.join(',')}
  ))
INNER JOIN tariff_records on tariff_records.classification_id = classifications.id and length(tariff_records.hts_1) > 0
INNER JOIN (#{inner_query}) inner_query ON inner_query.id = products.id"

        q
      end

      def inner_query
        q = <<-QRY
SELECT DISTINCT products.id
FROM products
#{@no_brand_restriction ? "" : "INNER JOIN custom_values sap_brand ON sap_brand.custom_definition_id = #{@sap_brand.id} AND sap_brand.customizable_id = products.id AND sap_brand.boolean_value = 1" }
INNER JOIN classifications on classifications.product_id = products.id AND classifications.country_id IN (SELECT id FROM countries WHERE iso_code IN (
#{@custom_countries.blank? ? "'IT','US','CA','KR','JP','HK'" : @custom_countries.collect { |c| "'#{c}'" }.join(',')}))
INNER JOIN tariff_records on tariff_records.classification_id = classifications.id and length(tariff_records.hts_1) > 0
QRY
        if @custom_where.blank?
          q << "\n#{Product.need_sync_join_clause(sync_code)}\nWHERE #{Product.need_sync_where_clause()}"
        else
          q << "\n#{@custom_where}"
        end

        q << " ORDER BY products.updated_at ASC LIMIT #{max_products}"
        q
      end
    end
  end
end
