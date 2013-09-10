require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
require 'open_chain/custom_handler/ann_inc/ann_related_styles_support'
module OpenChain
  module CustomHandler
    module AnnInc
      class AnnOhlProductGenerator < OpenChain::CustomHandler::ProductGenerator
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
        include OpenChain::CustomHandler::AnnInc::AnnRelatedStylesSupport
        
        SYNC_CODE ||= 'ANN-PDM'


        #SchedulableJob compatibility
        def self.run_schedulable opts={}
          self.generate opts
        end
        
        def self.generate opts={}
          g = self.new(opts)
          g.ftp_file g.sync_csv
        end

        def initialize(opts={})
          super(opts)
          @cdefs = self.class.prep_custom_definitions [:approved_date,:approved_long,:long_desc_override, :related_styles]
          @used_part_countries = []
        end

        #superclass requires this method
        def sync_code
          SYNC_CODE
        end

        def ftp_credentials
          {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>"to_ecs/Ann/OHL"}
        end

        def sync_csv
          super(false) #no headers
        end

        def preprocess_row outer_row
          explode_lines_with_related_styles(outer_row) do |row|
            pc_key = "#{row[0]}-#{row[4]}"
            local_row = [row]
            if @used_part_countries.include? pc_key
              local_row = []
            else 
              @used_part_countries << pc_key  
            end
            local_row
          end
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
            cd_s(@cdefs[:long_desc_override].id),
            cd_s(@cdefs[:related_styles].id),
          ]
          r = "SELECT #{fields.join(', ')}
FROM products
INNER JOIN (SELECT classifications.id, classifications.product_id, countries.iso_code 
  FROM classifications 
  INNER JOIN countries ON classifications.country_id = countries.id AND countries.iso_code IN (\"US\",\"CA\")
) as classifications on classifications.product_id = products.id
INNER JOIN tariff_records on tariff_records.classification_id = classifications.id and length(tariff_records.hts_1) > 0
LEFT OUTER JOIN sync_records on sync_records.syncable_type = 'Product' and sync_records.syncable_id = products.id and sync_records.trading_partner = '#{sync_code}'
INNER JOIN custom_values AS a_date ON a_date.custom_definition_id = #{@cdefs[:approved_date].id} AND a_date.customizable_id = classifications.id and a_date.date_value is not null
"
          w = "WHERE (sync_records.confirmed_at IS NULL OR sync_records.sent_at > sync_records.confirmed_at OR  sync_records.sent_at < products.updated_at)"
          r << (@custom_where ? @custom_where : w)
          #US must be in file before Canada per OHL spec
          r << " ORDER BY products.id, classifications.iso_code DESC, tariff_records.line_number"
          r
        end
      end
    end
  end
end
