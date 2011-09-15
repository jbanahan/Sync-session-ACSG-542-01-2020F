module OpenChain
  module Report
    class StaleTariffs
      # Run the report, no settings needed
      def self.run_report run_by, settings={}
        raise "You cannot run this report because you're not from company: #{Company.where(:master=>true).first.name}" unless run_by.company.master?
        raise "You cannot run this report because you don't have permission to view products." unless run_by.view_products?
        
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"Stale Tariffs"
        
        heading_row = sheet.row(0)
        heading_row.push ModelField.find_by_uid(:prod_uid).label
        heading_row.push ModelField.find_by_uid(:class_cntry_name).label
        heading_row.push "HTS #"

        row_cursor = 1
        ["hts_1","hts_2","hts_3"].each do |field|
          result = StaleTariffs.get_query_result(field)
          result.each do |result_row|
            sheet_row = sheet.row(row_cursor)
            (0..2).each {|i| sheet_row.push result_row[i]}
            row_cursor += 1
          end
        end

        if row_cursor ==1 #we haven't written any records
          sheet.row(row_cursor)[0] = "Congratulations! You don't have any stale tariffs."
        end

        t = Tempfile.new(['stale_tariffs','.xls'])
        wb.write t.path
        t
      end

      private
      def self.get_query_result(hts_field)
        sql = "select p.unique_identifier, ctr.name, tr.#{hts_field} from tariff_records tr "\
            "inner join classifications c on tr.classification_id = c.id "\
            "inner join countries ctr on ctr.id = c.country_id "\
            "inner join products p on c.product_id = p.id "\
            "left outer join official_tariffs ot on c.country_id = ot.country_id and tr.#{hts_field} = ot.hts_code "\
            "where ot.id is null and tr.#{hts_field} is not null and length(tr.#{hts_field})>0;"
        TariffRecord.connection.execute(sql)
      end
    end
  end
end
