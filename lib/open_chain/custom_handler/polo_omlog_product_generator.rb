require 'open_chain/custom_handler/product_generator'
module OpenChain
  module CustomHandler
    class PoloOmlogProductGenerator < ProductGenerator
      def sync_code
        "omlog-product"
      end
      def ftp_credentials
        {:server=>'77.93.255.102',:username=>'polo',:password=>'Z%JZp#yUxxH7'}
      end
      def sync_xls
        wb = Spreadsheet::Workbook.new
        sht = wb.create_worksheet :name=>'Results'
        cursor = 0
        sync do |rv|
          csm_numbers = rv[1].split("\n")
          csm_numbers.each do |c|
            row = sht.row(cursor)
            rv.each {|k,v| row[k] = (k==1 ? c : v)}
            cursor += 1
          end
        end
        if cursor > 1
          t = Tempfile.new(['ProductSync','.xls'])
          wb.write t
          return t
        else
          return nil
        end
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
tariff_records.hts_2 as 'Tariff - HTS Code 2',
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
