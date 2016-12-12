module OpenChain
  module Report
    class StaleTariffs
      # Run the report, no settings needed
      def self.run_report run_by, settings={}
        raise "You cannot run this report because you're not from company: #{Company.where(:master=>true).first.name}" unless run_by.company.master?
        raise "You cannot run this report because you don't have permission to view products." unless run_by.view_products?

        countries = settings["countries"]
        importer_ids = settings["importer_ids"]
        
        wb = XlsMaker.new_workbook
        
        {"hts_1" => "HTS #1", "hts_2" => "HTS #2", "hts_3" => "HTS #3"}.each_pair do |field, name|
          sheet = wb.create_worksheet :name=>"Stale Tariffs #{name}"
          heading_row = sheet.row(0)
          heading_row.push ModelField.find_by_uid(:cmp_name).label
          heading_row.push ModelField.find_by_uid(:prod_uid).label
          heading_row.push ModelField.find_by_uid(:class_cntry_name).label
          heading_row.push name
          row_cursor = 1


          result = StaleTariffs.get_query_result(field, countries, importer_ids)
          result.each do |result_row|
            sheet_row = sheet.row(row_cursor)
            (0..3).each {|i| sheet_row.push result_row[i]}
            row_cursor += 1
          end

          if row_cursor ==1 #we haven't written any records
            sheet.row(row_cursor)[0] = "Congratulations! You don't have any stale tariffs."
          end
        end

        t = Tempfile.new(['stale_tariffs','.xls'])
        wb.write t.path
        t
      end

      private
      def self.get_query_result(hts_field, countries, importer_ids)
        sql = "select comp.name, p.unique_identifier, ctr.name, tr.#{hts_field} " +
            "FROM tariff_records tr " +
            "inner join classifications c on tr.classification_id = c.id " +
            "inner join countries ctr on ctr.id = c.country_id " +
            "inner join products p on c.product_id = p.id " +
            "left outer join companies comp ON comp.id = p.importer_id " +
            "left outer join official_tariffs ot on c.country_id = ot.country_id and tr.#{hts_field} = ot.hts_code " +
            "where ot.id is null and tr.#{hts_field} is not null and length(tr.#{hts_field})>0"

        if countries.try(:length).to_i > 0
          sql += " AND ctr.iso_code IN (" + countries.map {|c| ActiveRecord::Base.sanitize c }.join(", ") + ")"
        end

        if importer_ids.try(:length).to_i > 0
          sql += " AND p.importer_id IN (" + importer_ids.map {|i| i.to_i}.join(", ") + ")"
        end

        sql += " ORDER BY ctr.name, comp.name, tr.#{hts_field}, p.unique_identifier"

        TariffRecord.connection.execute(sql)
      end
    end
  end
end
