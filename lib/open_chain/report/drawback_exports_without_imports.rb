module OpenChain
  module Report
    class DrawbackExportsWithoutImports
      def self.permission? user
        user.company.master? && user.view_drawback? 
      end
      def self.run_report run_by, settings={}
        raise "You do not have permission to run this report." unless permission? run_by
        wb = Spreadsheet::Workbook.new
        s = wb.create_worksheet :name=>"Unmatched Exports"
        lines = DutyCalcExportFileLine.not_in_imports.where("export_date between ? and ?",settings['start_date'],settings['end_date'])
        cursor = 0
        r = s.row(cursor)
        ["Export Date","Part Number","Ref 1","Ref 2","Quantity"].each_with_index do |t,i|
          r[i] = t
        end
        cursor += 1
        lines.each do |ln|
          r = s.row(cursor)
          r[0] = ln.export_date
          r[1] = ln.part_number
          r[2] = ln.ref_1
          r[3] = ln.ref_2
          r[4] = ln.quantity
          cursor += 1
        end
        t = Tempfile.new(['DrawbackExportsWithoutImports','.xls'])
        wb.write t.path
        t
      end
    end
  end
end
