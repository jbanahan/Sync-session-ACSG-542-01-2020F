module OpenChain
  module Report
    module ReportHelper
      DATE_FORMAT = Spreadsheet::Format.new :number_format=>'YYYY-MM-DD'
      #writes the results of the query including headings into the sheet starting at cell A1
      def table_from_query sheet, query
        rs = Entry.connection.execute query
        cursor = 0
        row = sheet.row(cursor)
        rs.fields.each {|f| row.push << f }
        cursor += 1
        rs.each do |vals|
          row = sheet.row(cursor)
          vals.each_with_index do |v,col|
            write_val sheet, row, cursor, col, v
          end
          cursor += 1
        end
      end
      def write_val sheet, row, row_num, col_num, val
        v = val
        v = v.to_f if v.is_a?(BigDecimal)
        row[col_num] = v
        if v.respond_to?(:strftime)
          sheet.row(row_num).set_format(col_num,DATE_FORMAT)
        end
      end
      def workbook_to_tempfile wb, prefix
        t = Tempfile.new([prefix,'.xls'])
        wb.write t.path
        t
      end
      def sanitize_date_string dstr
        Date.parse(dstr).strftime("%Y-%m-%d")
      end
    end
  end
end
