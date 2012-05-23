module OpenChain
  module Report
    class ProductsWithoutAttachments
      FIELDS = [:prod_uid,:prod_changed_at]
      #run the report
      #no settings needed
      def self.run_report run_by, settings={}
        records = Product.select("DISTINCT products.*").
          joins("LEFT OUTER JOIN linked_attachments ON linked_attachments.attachable_id = products.id AND linked_attachments.attachable_type = \"Product\"").
          joins("LEFT OUTER JOIN attachments ON attachments.attachable_id = products.id AND attachments.attachable_type = \"Product\"").
          where("attachments.id is NULL AND linked_attachments.id is NULL")
        records = Product.search_secure run_by, records
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"Products Without Attachments"
        row_cursor = 0
        row = sheet.row row_cursor
        row.default_format = XlsMaker::HEADER_FORMAT
        FIELDS.each {|f| row.push ModelField.find_by_uid(f).label}
        row_cursor += 1
        if records.empty?
          row = sheet.row row_cursor
          row.push "No records found."
          row_cursor += 1
        else
          records.each do |p|
            row = sheet.row row_cursor
            FIELDS.each {|f| row.push ModelField.find_by_uid(f).process_export p, run_by}
            row_cursor += 1
          end
        end
        t = Tempfile.new(['products_without_attachments','.xls'])
        wb.write t.path
        t
      end
    end
  end
end
