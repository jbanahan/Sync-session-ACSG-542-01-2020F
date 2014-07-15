require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/alliance_product_support'

module OpenChain
  module CustomHandler
    class DasProductGenerator < ProductGenerator
      include AllianceProductSupport

      SYNC_CODE = 'das-product'

      def sync_code
        SYNC_CODE
      end

      def generate
        ftp_file sync_fixed_position
      end
      
      def remote_file_name
        "DAPART.DAT"
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
        unit_cost = CustomDefinition.where(label: 'Unit Cost', module_type: 'Product').first
        coo = CustomDefinition.where(label: 'COO', module_type: 'Product').first
        "SELECT products.id, unique_identifier, name,
        #{cd_s(unit_cost.try(:id), nil, true)},
        #{cd_s(coo.try(:id),nil, true)},
        tr.hts_1 FROM products
        INNER JOIN classifications c ON c.product_id = products.id AND c.country_id = (SELECT id FROM countries WHERE iso_code = \"US\")
        INNER JOIN tariff_records tr ON tr.classification_id = c.id 
        #{Product.need_sync_join_clause(sync_code)}
        WHERE #{Product.need_sync_where_clause()}"
      end

      def self.run_schedulable
        self.new.generate
      end
    end
  end
end
