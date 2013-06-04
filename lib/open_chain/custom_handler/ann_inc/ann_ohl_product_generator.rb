require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
module OpenChain
  module CustomHandler
    module AnnInc
      class AnnOhlProductGenerator < OpenChain::CustomHandler::ProductGenerator
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport 
        
        SYNC_CODE ||= 'ANN-PDM'

        def initialize(opts={})
          super(opts)
          @cdefs = prep_custom_definitions [:approved_date,:approved_long,:long_desc_override]
        end

        #superclass requires this method
        def sync_code
          SYNC_CODE
        end

        def sync_csv
          super(false) #no headers
        end
        
        def before_csv_write cursor, vals
          clean_string_values vals

          #ISO code must be uppercase
          vals[4].upcase!

          #replace the long description with the override value from the classification
          #unless the override is blank
          vals[1] = vals[5] unless vals[5].blank?

          #remove the long description override value
          vals.pop

          vals
        end

        def query
          fields = [
            'products.id',
            'products.unique_identifier',
            cd_s(@cdefs[:approved_long].id),
            'tariff_records.hts_1',
            'ifnull(tariff_records.schedule_b_1,"")',
            'classifications.iso_code',
            cd_s(@cdefs[:long_desc_override].id)
          ]
          r = "SELECT #{fields.join(', ')}
FROM products
INNER JOIN (SELECT classifications.id, classifications.product_id, countries.iso_code 
  FROM classifications 
  INNER JOIN countries ON classifications.country_id = countries.id AND countries.iso_code IN (\"US\",\"CA\")
) as classifications on classifications.product_id = products.id
LEFT OUTER JOIN tariff_records on tariff_records.classification_id = classifications.id
LEFT OUTER JOIN sync_records on sync_records.syncable_type = 'Product' and sync_records.syncable_id = products.id and sync_records.trading_partner = '#{sync_code}'
INNER JOIN custom_values AS a_date ON a_date.custom_definition_id = #{@cdefs[:approved_date].id} AND a_date.customizable_id = products.id and a_date.date_value is not null
"
          w = "WHERE (sync_records.confirmed_at IS NULL OR sync_records.sent_at > sync_records.confirmed_at OR  sync_records.sent_at < products.updated_at)
AND length(tariff_records.hts_1) > 0
"
          r << (@custom_where ? @custom_where : w)
          #US must be in file before Canada per OHL spec
          r << "ORDER BY products.id, classifications.iso_code DESC"
        end
      end
    end
  end
end
