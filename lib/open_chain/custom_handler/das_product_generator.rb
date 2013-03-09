require 'open_chain/custom_handler/product_generator'

module OpenChain
  module CustomHandler
    class DasProductGenerator < ProductGenerator
      def ftp_credentials
        {:username=>'VFITRACK',:password=>'RL2VFftp',:server=>'ftp2.vandegriftinc.com',:folder=>'/_to_ecs/alliance_products',:remote_file_name=>'x.csv'}
      end

      def remote_file_name
        "#{Time.now.strftime("%Y%m%d%H%M%S%L")}-DAPART.DAT"
      end

      def fixed_position_map
        [
          {:len=>15}, #unique identifier
          {:len=>40}, #name
          {:len=>6}, #unit cost
          {:len=>2}, #country of origin
          {:len=>10} #hts
        ]
      end

      def query
        "select products.id, unique_identifier, name, 
(select decimal_value from custom_values where custom_definition_id = 2 and customizable_id = products.id) as \"Unit Cost\", 
(select string_value from custom_values where custom_definition_id = 6 and customizable_id = products.id) as \"COO\", 
tr.hts_1
from products
inner join classifications c on c.product_id = products.id and c.country_id = (select id from countries where iso_code = \"US\")
inner join tariff_records tr on tr.classification_id = c.id"
      end
    end
  end
end
