module OpenChain
  module Report
    class AttachmentsNotMatched
      #run the report
      #no settings needed
      def self.run_report run_by, settings={}
        records = LinkableAttachment.joins("LEFT OUTER JOIN linked_attachments ON linkable_attachments.id = linked_attachments.linkable_attachment_id").
          where("linked_attachments.id is null")
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"Attachments Not Matched"
        row_cursor = 0
        row = sheet.row row_cursor
        row.default_format = XlsMaker::HEADER_FORMAT
        row.push "File Name"
        row.push "Upload Date"
        row.push "Match Field"
        row.push "Match Value"
        row_cursor += 1
        if records.empty?
          row = sheet.row row_cursor
          row.push "No records found."
          row_cursor += 1
        else
          records.each do |a|
            row = sheet.row row_cursor
            row.push a.attachment.attached_file_name
            row.push a.created_at
            mf = ModelField.find_by_uid(a.model_field_uid)
            row.push (mf.nil? ? "UNKNOWN" : mf.label)
            row.push a.value
            row_cursor += 1
          end
        end
        t = Tempfile.new(['attachments_not_matched','.xls'])
        wb.write t.path
        t
      end
    end
  end
end
