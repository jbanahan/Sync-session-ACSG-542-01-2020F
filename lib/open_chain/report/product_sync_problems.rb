module OpenChain
  module Report
    class ProductSyncProblems
      def self.run_report run_by, settings={}
        records = SyncRecord.problems.joins("INNER JOIN products ON sync_records.syncable_id = products.id AND sync_records.syncable_type = \"Product\"")
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"Attachments Not Matched"
        row_cursor = 0
        row = sheet.row row_cursor
        row.default_format = XlsMaker::HEADER_FORMAT
        row.push "Product"
        row.push "System"
        row.push "Record Sent"
        row.push "Confirmation Received"
        row.push "Confirmation File Name"
        row.push "Failure Message"
        row_cursor += 1

        records.each do |r|
          row = sheet.row row_cursor
          row.push r.syncable.unique_identifier
          row.push r.trading_partner
          row.push r.sent_at
          row.push r.confirmed_at
          row.push r.confirmation_file_name
          row.push r.failure_message
          row_cursor += 1
        end

        t = Tempfile.new(['product_sync_problems','.xls'])
        wb.write t.path
        t
      end
    end
  end
end
