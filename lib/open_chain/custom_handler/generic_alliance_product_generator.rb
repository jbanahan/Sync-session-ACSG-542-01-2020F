require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/alliance_product_support'
module OpenChain
  module CustomHandler
    # Generates the stanadard product output file for sending to the Alliance CAT
    class GenericAllianceProductGenerator < ProductGenerator
      include AllianceProductSupport

      #this is the main method you should call
      def self.sync importer
        g = OpenChain::CustomHandler::GenericAllianceProductGenerator.new importer
        f = g.sync_fixed_position
        g.ftp_file f
        f.unlink
        nil
      end

      def initialize importer
        # Anything other than a company we'll assume is suitable to be used to lookup a company
        unless importer.nil? || importer.is_a?(Company)
          importer = Company.where(:id => importer).first
        end

        raise ArgumentError, "Importer is required and must have an alliance customer number" unless importer && !importer.alliance_customer_number.blank?
        @importer = importer
      end
      
      def remote_file_name
        "#{Time.now.to_i}-#{@importer.alliance_customer_number}.DAT"
      end

      def fixed_position_map
        [
          {:len=>15}, #part number
          {:len=>40}, #name
          {:len=>10}, #hts 1
          {:len=>2}   #country of origin
        ]
      end

      def query
        coo = CustomDefinition.find_by_label_and_module_type("Country of Origin","Product")
        pn = CustomDefinition.find_by_label_and_module_type("Part Number","Product")
        "SELECT products.id,
#{cd_s pn.id},
products.name,
tariff_records.hts_1,
IF(length(#{cd_s coo.id, true})=2,#{cd_s coo.id, true},\"\")
FROM products
INNER JOIN classifications on classifications.country_id = (SELECT id FROM countries WHERE iso_code = \"US\") AND classifications.product_id = products.id
INNER JOIN tariff_records on length(tariff_records.hts_1)=10 AND tariff_records.classification_id = classifications.id
WHERE products.importer_id = #{@importer.id} AND length(#{cd_s pn.id, true})>0
        "
      end
    end
  end
end
