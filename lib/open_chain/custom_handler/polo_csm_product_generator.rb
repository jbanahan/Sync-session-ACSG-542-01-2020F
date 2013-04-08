require 'open_chain/custom_handler/product_generator'
module OpenChain
  module CustomHandler
    class PoloCsmProductGenerator < ProductGenerator

      def generate
        ftp_file sync_csv
      end

      def sync_code
        'csm_product'
      end
      
      #overriding to handle special splitting of CSM numbers
      def sync_csv include_headers=true
        f = Tempfile.new(['ProductSync','.csv'])
        cursor = 0
        sync do |rv|
          if include_headers || cursor > 0
            csm_numbers = rv[1] ? rv[1].split("\n") : []
            csm_numbers.each do |c|
              max_col = rv.keys.sort.last
              row = []
              (0..max_col).each do |i|
                v = i==1 ? c : rv[i]
                v = "" if v.blank?
                v = v.hts_format if [10,13,16].include?(i)
                row << v.to_s.gsub(/\r?\n/, " ")
              end
              f << row.to_csv
            end
          end
          cursor += 1
        end
        f.flush
        if (include_headers && cursor > 1) || cursor > 0
          return f
        else
          f.unlink
          return nil
        end
      end
      
      #custom remote file name required by trading partner (yes, we know that granularity to the second is bad)
      def remote_file_name
        "Chain#{Time.now.strftime("%Y%m%d%H%M%S")}.csv"
      end

      def ftp_credentials
        {:server=>'ftp.chain.io',:username=>'polo',:password=>'pZZ117',:folder=>'/_to_csm',:remote_file_name=>remote_file_name}
      end

      def query
        q = "SELECT products.id, 
#{cd_s 101},
#{cd_s CustomDefinition.find_by_label('CSM Number').id},
#{cd_s 2},
'IT' as 'Classification - Country ISO Code',
#{cd_s 3},
#{cd_s 4},
products.unique_identifier as 'Style',
#{cd_s 6},
products.name as 'Name',
#{cd_s 8},
tariff_records.hts_1 as 'Tariff - HTS Code 1',
(select category from official_quotas where official_quotas.hts_code = tariff_records.hts_1 and official_quotas.country_id = classifications.country_id LIMIT 1) as 'Tariff - 1 - Quota Category',
(select general_rate from official_tariffs where official_tariffs.hts_code = tariff_records.hts_1 and official_tariffs.country_id = classifications.country_id) as 'Tariff - 1 - General Rate',
tariff_records.hts_2 as 'Tariff - HTS Code 2',
(select category from official_quotas where official_quotas.hts_code = tariff_records.hts_2 and official_quotas.country_id = classifications.country_id LIMIT 1) as 'Tariff - 2 - Quota Category',
(select general_rate from official_tariffs where official_tariffs.hts_code = tariff_records.hts_2 and official_tariffs.country_id = classifications.country_id) as 'Tariff - 2 - General Rate',
tariff_records.hts_3 as 'Tariff - HTS Code 3',
(select category from official_quotas where official_quotas.hts_code = tariff_records.hts_3 and official_quotas.country_id = classifications.country_id LIMIT 1) as 'Tariff - 3 - Quota Category',
(select general_rate from official_tariffs where official_tariffs.hts_code = tariff_records.hts_3 and official_tariffs.country_id = classifications.country_id) as 'Tariff - 3 - General Rate',"
        (9..84).each do |i|
          q << cd_s(i)+","
        end
        q << cd_s(102)+","
        (85..94).each do |i|
          q << cd_s(i)+","
        end
        q << cd_s(95) 
        q << "
FROM products
LEFT OUTER JOIN classifications ON classifications.product_id = products.id
LEFT OUTER JOIN tariff_records ON tariff_records.classification_id = classifications.id 
LEFT OUTER JOIN custom_values csm_v on csm_v.custom_definition_id = (SELECT id from custom_definitions where label = 'CSM Number') and customizable_id = products.id 
LEFT OUTER JOIN sync_records on sync_records.syncable_id = products.id AND sync_records.trading_partner = '#{sync_code}' " 
        w = "WHERE classifications.country_id = (SELECT id FROM countries WHERE iso_code = 'IT')
AND length(tariff_records.hts_1) > 0 and length(csm_v.text_value) > 0 AND
(sync_records.confirmed_at IS NULL OR sync_records.sent_at > sync_records.confirmed_at OR  sync_records.sent_at < products.updated_at)"
        q << (@custom_where ? @custom_where : w)
        q
      end
    end
  end
end
