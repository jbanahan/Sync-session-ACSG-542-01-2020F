require 'open_chain/custom_handler/product_generator'
module OpenChain
  module CustomHandler
    class PoloOmlogV2ProductGenerator < ProductGenerator

      def self.run_schedulable opts={}
        h = self.new
        h.ftp_file h.sync_csv
      end
      def sync_code
        "omlog-product-v2"
      end
      def ftp_credentials
        {:server=>'ftp.omlogasia.com',:username=>'ftp06user21',:password=>'kXynC3jm',:folder=>'chain'}
      end
      #overriding to handle special splitting of CSM numbers
      def sync_csv include_headers=true
        f = Tempfile.new(['ProductSync','.csv'])
        cursor = 0
        sync do |rv|
          if include_headers || cursor > 0
            csm_numbers = rv[1].blank? ? [''] : rv[1].split("\n")
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
        ((9..79).to_a + [132, 137, 142, 147, 84, 102] + (85..95).to_a).each do |i|
          q << cd_s(i)+","
        end
        q << "tariff_records.line_number as 'Tariff - HTS Row'"
        q << "
FROM products
INNER JOIN classifications ON classifications.product_id = products.id
INNER JOIN countries on classifications.country_id = countries.id AND countries.iso_code = 'IT'
INNER JOIN tariff_records ON tariff_records.classification_id = classifications.id AND length(tariff_records.hts_1) > 0"
        # If we have a custom where, then don't add the need_sync join clauses.
        if @custom_where.blank?
          q << "\n#{Product.need_sync_join_clause(sync_code)} "
          q << "\nWHERE #{Product.need_sync_where_clause()}"
        else
          q << "\n#{@custom_where}"
        end
        q
      end
    end
  end
end
