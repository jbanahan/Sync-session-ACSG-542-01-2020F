require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
require 'open_chain/custom_handler/ann_inc/ann_related_styles_support'

module OpenChain
  module CustomHandler
    module AnnInc
      class AnnMilgramProductGenerator < OpenChain::CustomHandler::ProductGenerator
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport 
        include OpenChain::CustomHandler::AnnInc::AnnRelatedStylesSupport

        SYNC_CODE ||= 'ANN-MIL'
        
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
          @cdefs = self.class.prep_custom_definitions [:approved_date,:approved_long,:long_desc_override,:manual_flag,:oga_flag,:fta_flag,:set_qty,:related_styles]
        end

        def sync_code
          SYNC_CODE
        end
        def ftp_credentials
          {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>"to_ecs/Ann/MIL"}
        end

        def sync_csv
          @sets_found = []
          super(false, {:col_sep=>"\t"}) #no headers
        end

        def preprocess_row outer_row
          explode_lines_with_related_styles(outer_row) do |row|
            r = []

            #set proper Y/N for booleans
            (6..8).each {|i| row[i] = fix_boolean(row[i])}

            if row[5]=='Y' #handle sets
              if !@sets_found.include?(row[0]) #we need the header record for this set
                hr = {}
                row.each {|k,v| hr[k] = v}
                hr[1] = '' #no line number
                hr[3] = '' #no quantity
                hr[4] = '' #no hts
                @sets_found << row[0]
                r << hr
              end
              r << row
            else
              row[1] = '' #only send line number for set details
              row[3] = '' #only send quantity for set details
              r << row
            end
            r
          end
        end

        def before_csv_write cursor, vals
          clean_string_values vals

          #long description override
          vals[2] = vals.last unless vals.last.blank?
          vals.pop

          vals
        end

        def query
          fields = [
            'products.id',
            'products.unique_identifier',
            'tariff_records.line_number',
            cd_s(@cdefs[:approved_long].id),
            cd_s(@cdefs[:set_qty].id),
            'tariff_records.hts_1',
            'IF((SELECT count(*) FROM tariff_records trx WHERE classifications.id = trx.classification_id)>1,"Y","N")',
            cd_s(@cdefs[:oga_flag].id),
            cd_s(@cdefs[:fta_flag].id),
            cd_s(@cdefs[:manual_flag].id),
            cd_s(@cdefs[:long_desc_override].id),
            cd_s(@cdefs[:related_styles].id)
          ]
          r = "SELECT #{fields.join(', ')}
FROM products
INNER JOIN (SELECT classifications.id, classifications.product_id, countries.iso_code 
  FROM classifications 
  INNER JOIN countries ON classifications.country_id = countries.id AND countries.iso_code = \"CA\"
) as classifications on classifications.product_id = products.id
INNER JOIN tariff_records on tariff_records.classification_id = classifications.id and length(tariff_records.hts_1) > 0
#{Product.need_sync_join_clause(sync_code)} 
INNER JOIN custom_values AS a_date ON a_date.custom_definition_id = #{@cdefs[:approved_date].id} AND a_date.customizable_id = classifications.id and a_date.date_value is not null
"
          w = "WHERE #{Product.need_sync_where_clause()}"
          r << (@custom_where ? @custom_where : w)
          r
        end

        private
        def fix_boolean src
          (src.blank? || src=='0') ? 'N' : 'Y'
        end
      end
    end
  end
end
