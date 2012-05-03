module OpenChain
  module Report
    class ContainersReleased
      FIELDS = [:ent_container_nums,:ent_entry_num,:ent_release_date,:ent_arrival_date,:ent_export_date,:ent_first_release]
      # Run the report
      # settings = {'arrival_date_start' => 2010-01-01, 'arrival_date_end'=> 2010-01-30, customer_numbers => ['1','2','3'] }
      def self.run_report run_by, settings={}
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"Containers Released"
        if run_by.view_entries?
          model_fields = FIELDS.collect {|f| ModelField.find_by_uid f}
          entries = Entry.search_secure run_by, Entry.where("entries.container_numbers is not null AND length(entries.container_numbers) > 0")
          entries = entries.where("customer_number IN (?)",settings['customer_numbers']) unless settings['customer_numbers'].blank?
          entries = entries.where("arrival_date >= ?",settings['arrival_date_start']) unless settings['arrival_date_start'].blank?
          entries = entries.where("arrival_date <= ?",settings['arrival_date_end']) unless settings['arrival_date_end'].blank?
          row_cursor = 0
          row = sheet.row row_cursor
          row.default_format = XlsMaker::HEADER_FORMAT
          row_cursor += 1
          model_fields.each {|mf| row.push mf.label}
          entries.each_with_index do |e,i|
            e.container_numbers.each_line do |c|
              row = sheet.row row_cursor
              row.push c.strip
              model_fields.each_with_index {|mf,idx| row.push mf.process_export(e,run_by) unless idx==0}
              row_cursor += 1
            end
          end
        else
          sheet.row(0).push "You do not have permission to run this report."
        end
        t = Tempfile.new(['containers_released','.xls'])
        wb.write t.path
        t
      end
    end
  end
end
