require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/alliance_product_support'

module OpenChain
  module CustomHandler
    class CrocsProductGenerator < ProductGenerator
      include AllianceProductSupport
      def remote_file_name
        "#{Time.now.strftime("%Y%m%d%H%M%S%L")}-CROCS.DAT"
      end

      def fixed_position_map
        [
          {:len=>40}, #part_number
          {:len=>40}, #name
          {:len=>10} #hts
        ]
      end

      def query
        "select products.id, (select string_value from custom_values where custom_definition_id = 43 and customizable_id = products.id) as \"Style\", 
products.name, tr.hts_1
from products
inner join classifications c on c.product_id = products.id and c.country_id = (select id from countries where iso_code = \"US\")
inner join tariff_records tr on tr.classification_id = c.id
where products.importer_id = (select id from companies where system_code = \"CROCS\")"
      end
    end
  end
end

