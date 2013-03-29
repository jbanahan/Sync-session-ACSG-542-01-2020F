require 'open_chain/custom_handler/product_generator'
module OpenChain
  module CustomHandler
    class PoloSapProductGenerator < ProductGenerator
      #Accepts 2 parameters :env=>:qa to send to qa ftp folder or :custom_where to replace the query where clause
      def initialize params = {}
        @env = params[:env]
        @custom_where = params[:custom_where]
      end
      def sync_code 
        'polo_sap'
      end
      def ftp_credentials
        {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>"to_ecs/Ralph_Lauren/sap_#{@env==:qa ? 'qa' : 'prod'}"}
      end
      def before_csv_write cursor, vals
        if vals[9]=='X'
          vals[3] = ''
        else
          vals[3] = vals[3].hts_format
        end
        vals.each {|v| v.gsub!(/[\r\n]/," ") if v.respond_to?(:gsub!)}
        vals
      end
      def query
        q = "SELECT products.id,
products.unique_identifier, 
#{cd_s 6},
(select iso_code from countries where countries.id = classifications.country_id) as 'Classification - Country ISO Code',
tariff_records.hts_1 as 'Tariff - HTS Code 1',
#{cd_s 130},
#{cd_s 22},
#{cd_s 7},
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
INNER JOIN classifications on classifications.product_id = products.id
INNER JOIN tariff_records on tariff_records.classification_id = classifications.id
LEFT OUTER JOIN sync_records on sync_records.syncable_id = products.id AND sync_records.trading_partner = '#{sync_code}' " 
        w = "WHERE classifications.country_id IN (SELECT id FROM countries WHERE iso_code IN ('IT','US','CA')) 
AND (sync_records.confirmed_at IS NULL OR sync_records.sent_at > sync_records.confirmed_at OR  sync_records.sent_at < products.updated_at)"
        q << (@custom_where ? @custom_where : w)
        q
      end
    end
  end
end
