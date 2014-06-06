require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/alliance_product_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain
  module CustomHandler
    # Generates the stanadard product output file for sending to the Alliance CAT
    class GenericAllianceProductGenerator < ProductGenerator
      include AllianceProductSupport
      include VfitrackCustomDefinitionSupport

      def self.run_schedulable opts = {}
        sync Company.where(alliance_customer_number: opts['alliance_customer_number']).first
      end

      #this is the main method you should call
      def self.sync importer
        g = OpenChain::CustomHandler::GenericAllianceProductGenerator.new importer
        f = nil
        begin
          f = g.sync_fixed_position
          g.ftp_file f
        ensure
          f.close! unless f.nil? || f.closed?
        end
        nil
      end

      def initialize importer
        # Anything other than a company we'll assume is suitable to be used to lookup a company
        unless importer.nil? || importer.is_a?(Company)
          importer = Company.where(:id => importer).first
        end

        raise ArgumentError, "Importer is required and must have an alliance customer number" unless importer && !importer.alliance_customer_number.blank?
        @importer = importer

        @cdefs = self.class.prep_custom_definitions [:prod_country_of_origin, :prod_part_number, :prod_fda_product, :prod_fda_product_code, :prod_fda_temperature, :prod_fda_uom, 
                    :prod_fda_country, :prod_fda_mid, :prod_fda_shipper_id, :prod_fda_description, :prod_fda_establishment_no, :prod_fda_container_length, 
                    :prod_fda_container_width, :prod_fda_container_height, :prod_fda_contact_name, :prod_fda_contact_phone, :prod_fda_affirmation_compliance]
      end

      def sync
        super
        @importer.update_attributes! :last_alliance_product_push_at => Time.zone.now
      end

      def sync_code
        'Alliance'
      end
      
      def remote_file_name
        "#{Time.now.to_i}-#{@importer.alliance_customer_number}.DAT"
      end

      def preprocess_row row, opts = {}
        # We're going to exclude all the FDA columns unless the FDA Product indicator is true
        unless row[4] == "Y"
          (5..18).each {|x| row[x] = ""}
        end

        super row, opts
      end

      def fixed_position_map
        [
          {:len=>15}, #part number
          {:len=>40}, #name
          {:len=>10}, #hts 1
          {:len=>2},  #country of origin
          {:len=>1},  # FDA Product Code indicator flag
          {:len=>7},  # FDA Product Code
          {:len=>1},  # FDA Temperator
          {:len=>3},  # FDA UOM
          {:len=>2},  # FDA Country of Origin
          {:len=>15}, # FDA MID
          {:len=>15}, # FDA Shipper ID
          {:len=>40}, # FDA Description
          {:len=>11}, # FDA Establishment #
          {:len=>4},  # FDA Container Length
          {:len=>4},  # FDA Container Width
          {:len=>4},  # FDA Container Height
          {:len=>10},  # FDA Contact Name
          {:len=>10},  # FDA Contact Phone
          {:len=>3}  # FDA Affirmation of Compliance
        ]
      end

      def query
        <<-QRY
SELECT products.id,
#{cd_s @cdefs[:prod_part_number].id},
products.name,
tariff_records.hts_1,
IF(length(#{cd_s @cdefs[:prod_country_of_origin].id, true})=2,#{cd_s @cdefs[:prod_country_of_origin].id, true},""),
IF(#{cd_s @cdefs[:prod_fda_product].id, true} = 1, "Y", "N"),
#{cd_s @cdefs[:prod_fda_product_code].id},
#{cd_s @cdefs[:prod_fda_temperature].id},
#{cd_s @cdefs[:prod_fda_uom].id},
#{cd_s @cdefs[:prod_fda_country].id},
#{cd_s @cdefs[:prod_fda_mid].id},
#{cd_s @cdefs[:prod_fda_shipper_id].id},
#{cd_s @cdefs[:prod_fda_description].id},
#{cd_s @cdefs[:prod_fda_establishment_no].id},
#{cd_s @cdefs[:prod_fda_container_length].id},
#{cd_s @cdefs[:prod_fda_container_width].id},
#{cd_s @cdefs[:prod_fda_container_height].id},
#{cd_s @cdefs[:prod_fda_contact_name].id},
#{cd_s @cdefs[:prod_fda_contact_phone].id},
#{cd_s @cdefs[:prod_fda_affirmation_compliance].id}
FROM products
INNER JOIN classifications on classifications.country_id = (SELECT id FROM countries WHERE iso_code = "US") AND classifications.product_id = products.id
INNER JOIN tariff_records on length(tariff_records.hts_1)=10 AND tariff_records.classification_id = classifications.id
#{Product.need_sync_join_clause(sync_code)} 
WHERE 
#{Product.need_sync_where_clause()} 
AND products.importer_id = #{@importer.id} AND length(#{cd_s@cdefs[:prod_part_number].id, true})>0
QRY
      end
    end
  end
end
