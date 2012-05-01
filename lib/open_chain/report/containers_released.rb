module OpenChain
  module Report
    class ContainersReleased
      # Run the report
      # settings = {'arrival_date_start' => 2010-01-01, 'arrival_date_end'=> 2010-01-30 }
      def self.run_report run_by, settings={}
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"Containers Released"
        entries = Entry.search_secure run_by, Entry.where("entries.container_numbers is not null AND length(entries.container_numbers) > 0")
        row_cursor = 1
        entries.each_with_index do |e,i|
          e.container_numbers.each_line do |c|
            row = sheet.row row_cursor
            row.push c.strip
            row.push e.entry_number
            row.push e.release_date
            row.push e.arrival_date
            row.push e.export_date
            row.push e.first_release_date
            row_cursor += 1
          end
        end
        t = Tempfile.new(['containers_released','.xls'])
        wb.write t.path
        t
      end
    end
  end
end
