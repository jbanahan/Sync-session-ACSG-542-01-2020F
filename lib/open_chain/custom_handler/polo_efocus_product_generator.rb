module OpenChain
  module CustomHandler
    class PoloEfocusProductGenerator

      SYNC_CODE = 'efocus-product'
      def generate
        ftp_file sync_xls
      end

      def sync_xls
        synced_products = []
        wb = Spreadsheet::Workbook.new
        sht = wb.create_worksheet :name=>'Results'
        rt = result_table
        cursor = 0
        row = sht.row(cursor)
        rt.fields.each_with_index do |f,i|
          row[i] = f
        end
        cursor += 1
        rt.each do |vals|
          row = sht.row(cursor)
          vals.each_with_index {|v,i| row[i] = v}
          synced_products << vals[5]
          cursor +=1
        end
        synced_products.in_groups_of(100,false) do |uids|
          x = uids.collect {|u| "\"#{u}\""}
          Product.transaction do
            Product.connection.execute "DELETE FROM sync_records where syncable_id IN (select id from products where unique_identifier in (#{x.join(",")}));"
            Product.connection.execute "INSERT INTO sync_records (syncable_id,syncable_type,sent_at,confirmed_at,updated_at,created_at,trading_partner) 
 (select id, \"Product\",now(),now() + INTERVAL 1 MINUTE,now(),now(),\"#{SYNC_CODE}\" from products where unique_identifier in (#{x.join(",")}));"
          end
        end
        t = Tempfile.new(['BarthcoSync','.xls'])
        wb.write t
        t
      end

      def result_table
        Product.connection.execute(build_query)
      end
      def ftp_file file
        begin
          FtpSender.send_file('ftp.freightek.com','polo','polo541xm',file,{:folder=>'/ProductUpload'})
        ensure
          file.unlink
        end
      end

      private
      def build_query
        fields = [
          cd_s(1),
          cd_s(2),
          "\"US\" as `#{ModelField.find_by_uid(:class_cntry_iso).label}`",
          cd_s(3),
          cd_s(4),
          "IFNULL(products.unique_identifier,\"\") AS `#{ModelField.find_by_uid(:prod_uid).label}`",
          cd_s(6),
          "IFNULL(products.name,\"\") AS `#{ModelField.find_by_uid(:prod_name).label}`",
          "\"\" AS `Blank 1`",
          cd_s(8),
          "IFNULL(tariff_records.hts_1,\"\") AS `#{ModelField.find_by_uid(:hts_hts_1).label}`",
          "IFNULL((SELECT category FROM official_quotas WHERE official_quotas.hts_code = tariff_records.hts_1 AND official_quotas.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_1_qc).label}`",
          "IFNULL((SELECT general_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_1 AND official_tariffs.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_1_gr).label}`",
          "IFNULL(tariff_records.hts_2,\"\") AS `#{ModelField.find_by_uid(:hts_hts_2).label}`",
          "IFNULL((SELECT category FROM official_quotas WHERE official_quotas.hts_code = tariff_records.hts_2 AND official_quotas.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_2_qc).label}`",
          "IFNULL((SELECT general_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_2 AND official_tariffs.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_2_gr).label}`",
          cd_s(9),
          cd_s(10),
          cd_s(11),
          cd_s(12),
          cd_s(13),
          cd_s(14),
          cd_s(15),
          cd_s(16),
          cd_s(17),
          cd_s(18),
          cd_s(19),
          cd_s(20),
          cd_s(21),
          cd_s(22),
          cd_s(23),
          cd_s(24),
          cd_s(25),
          cd_s(26),
          cd_s(27),
          cd_s(28),
          cd_s(29),
          cd_s(30),
          cd_s(31),
          cd_s(32),
          cd_s(33),
          cd_s(34),
          cd_s(35),
          cd_s(36),
          cd_s(37),
          cd_s(38),
          cd_s(39),
          cd_s(40),
          cd_s(41),
          cd_s(42),
          cd_s(43),
          cd_s(44),
          cd_s(45),
          cd_s(46),
          cd_s(47),
          cd_s(48),
          cd_s(49),
          cd_s(50),
          cd_s(51),
          cd_s(52),
          cd_s(53),
          cd_s(54),
          cd_s(55),
          cd_s(56),
          cd_s(57),
          cd_s(58),
          cd_s(59),
          cd_s(60),
          cd_s(61),
          cd_s(62),
          cd_s(63),
          cd_s(64),
          cd_s(65),
          cd_s(66),
          cd_s(67),
          cd_s(68),
          cd_s(69),
          cd_s(70),
          cd_s(71),
          cd_s(72),
          "\"\" AS `Blank 2`",
          cd_s(73),
          cd_s(74),
          cd_s(75),
          cd_s(76),
          "IFNULL((SELECT system_code FROM companies where companies.id = products.vendor_id),\"\") AS `#{ModelField.find_by_uid(:prod_ven_syscode).label}`",
          cd_s(78),
          cd_s(79),
          cd_s(80),
          cd_s(81),
          cd_s(82),
          cd_s(83),
          cd_s(84),
          cd_s(102),
          cd_s(85),
          cd_s(86),
          cd_s(87),
          cd_s(88),
          cd_s(89),
          cd_s(90),
          cd_s(91),
          cd_s(92),
          cd_s(93),
          cd_s(94),
          cd_s(95),
          cd_s(131)
        ]
        "SELECT #{fields.join(", ")} 
FROM products 
INNER JOIN classifications on classifications.product_id = products.id and classifications.country_id = (select id from countries where iso_code = \"US\" LIMIT 1)
LEFT OUTER JOIN tariff_records on tariff_records.classification_id = classifications.id
LEFT OUTER JOIN sync_records on sync_records.syncable_type = 'Product' and sync_records.syncable_id = products.id and sync_records.trading_partner = '#{SYNC_CODE}'
WHERE (sync_records.confirmed_at IS NULL OR sync_records.sent_at > sync_records.confirmed_at OR  sync_records.sent_at < products.updated_at)
AND (select length(string_value) from custom_values where customizable_id = products.id and custom_definition_id = (select id from custom_definitions where label = \"Barthco Customer ID\")) > 0
"
      end

      def cd_s cd_id
        @definitions ||= {}
        if @definitions.empty?
          CustomDefinition.all.each {|cd| @definitions[cd.id] = cd}
        end
        cd = @definitions[cd_id]
        return "(SELECT \"\") as `Custom #{cd_id}`" unless cd #so report doesn't bomb if custom field is removed from system
        table_name = ''
        case cd.module_type
        when 'Product'
          table_name = 'products'
        when 'Classification'
          table_name = 'classifications'
        end
        
        r = "(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = #{table_name}.id AND custom_definition_id = #{cd.id}) as `#{cd.label}`"
      end
    end
  end
end
