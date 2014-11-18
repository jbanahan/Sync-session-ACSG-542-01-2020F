require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
require 'open_chain/custom_handler/ann_inc/ann_related_styles_support'
module OpenChain
  module CustomHandler
    module AnnInc
      # send updated product information to Ann's Zymmetry system
      class AnnZymProductGenerator < OpenChain::CustomHandler::ProductGenerator
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport 
        include OpenChain::CustomHandler::AnnInc::AnnRelatedStylesSupport
       
        SYNC_CODE ||= 'ANN-ZYM'

        #SchedulableJob compatibility
        def self.run_schedulable opts={}
          self.generate opts
        end
        
        def self.generate opts={}
          g = self.new(opts)
          begin
            g.ftp_file g.sync_csv
          end while g.row_count > 500
        end

        def initialize opts={}
          super(opts)
          @cdefs = self.class.prep_custom_definitions [:approved_date,:approved_long,:long_desc_override,:origin,:article,:related_styles]
        end

        def sync_code
          SYNC_CODE
        end
        def auto_confirm?
          false
        end
        def trim_fingerprint row
          fp = row.pop
          [fp,row]
        end
        def ftp_credentials
          {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>"to_ecs/Ann/ZYM"}
        end
        def preprocess_row outer_row, opts = {}
          explode_lines_with_related_styles(outer_row) do |row|
            r = []
            origins = row[3].blank? ? [''] : row[3].split("\n")
            origins.each do |o|
              x = {}
              row.each {|k,v| x[k] = (k==3 ? o : v)}
              r << x
            end
            r
          end
        end
        def before_csv_write cursor, vals
          clean_string_values vals

          #replace the long description with the override value from the classification
          #unless the override is blank
          vals[2] = vals[5] unless vals[5].blank?

          [2,3].each { |i| vals[i] = nil if vals[i].blank?} #prevents empty string from returning quotes

          #remove the long description override value
          vals.pop

          vals
        end
        def sync_csv
          super(false,col_sep:'|') #no headers, pipe delimited, no quoting
        end
        def query
          md5 = "md5(concat(
              ifnull(products.unique_identifier,''),
              classifications.iso_code,
              ifnull(#{cd_s(@cdefs[:approved_long].id, suppress_alias: true)},''),
              ifnull(#{cd_s(@cdefs[:origin].id, suppress_alias: true)},''),
              ifnull(tariff_records.hts_1,''),
              ifnull(#{cd_s(@cdefs[:long_desc_override].id, suppress_alias: true)},''),
              ifnull(#{cd_s(@cdefs[:related_styles].id, suppress_alias: true)},'')
            ))"
          fields = [
            'products.id',
            'products.unique_identifier',
            'classifications.iso_code',
            cd_s(@cdefs[:approved_long].id),
            cd_s(@cdefs[:origin].id),
            'tariff_records.hts_1',
            cd_s(@cdefs[:long_desc_override].id),
            cd_s(@cdefs[:related_styles].id),
            md5 
          ]
          r = "SELECT #{fields.join(', ')}
FROM products
INNER JOIN (SELECT classifications.id, classifications.product_id, countries.iso_code 
  FROM classifications 
  INNER JOIN countries ON classifications.country_id = countries.id AND countries.iso_code = \"US\"
) as classifications on classifications.product_id = products.id
INNER JOIN tariff_records on tariff_records.classification_id = classifications.id and length(tariff_records.hts_1) > 0 
#{Product.need_sync_join_clause(sync_code)} 
INNER JOIN custom_values AS a_date ON a_date.custom_definition_id = #{@cdefs[:approved_date].id} AND a_date.customizable_id = classifications.id and a_date.date_value is not null
INNER JOIN custom_values AS a_type ON a_type.custom_definition_id = #{@cdefs[:article].id} AND a_type.customizable_id = products.id and a_type.string_value = 'ZSCR'
"
          w = "WHERE #{Product.need_sync_where_clause()} AND (sync_records.fingerprint is null OR sync_records.fingerprint = '' OR sync_records.fingerprint <> convert(#{md5} using latin1))"
          r << (@custom_where ? @custom_where : w)
          r << " AND tariff_records.line_number = (select min(tr.line_number) from tariff_records tr where tr.classification_id = tariff_records.classification_id)"
          r << " LIMIT 500"
          r
        end
      end
    end
  end
end
