module OpenChain; module CustomHandler; module EddieBauer
  class EddieBauer7501Handler
    include OpenChain::CustomHandler::CustomFileCsvExcelParser

    def initialize custom_file
      @custom_file = custom_file
    end

    # Required for custom file processing
    def process user
      errors = create_and_send_report user.email, @custom_file
      send_errors user.email, errors unless errors.blank?
      nil
    end

    def can_view?(user)
      user.company.alliance_customer_number == 'EDDIE'
    end

    def create_and_send_report email, custom_file
      errors = []
      begin
        create_and_send_report! email, custom_file
      rescue => e
        errors << "Failed to process 7501 due to the following error: '#{e.message}'."
      end
      errors
    end

    def create_and_send_report! email, custom_file
      if File.extname(custom_file.path).downcase == ".xls"
        hts_hsh = collect_hts custom_file
        Tempfile.open(["eb_7501_audit", ".xls"]) do |report|
          perform_audit hts_hsh, custom_file, report
          send_report email, report
        end
      else
        raise "No CI Upload processor exists for #{File.extname(custom_file.path).downcase} file types."
      end
    end

    def collect_hts custom_file
      prod_uids = get_column(custom_file, 2).map{ |n| n[0..7] }
      extract_hts prod_uids
    end

    def extract_hts prod_uids
      prod_nums = {}
      Product.connection.exec_query(prod_query prod_uids).each do |row|
        hts = [row["hts_1"], row["hts_2"], row["hts_3"]].map(&:presence).compact.first.to_s
        prod_nums[row["unique_identifier"]] = hts
      end
      prod_nums
    end

    def perform_audit hts_hsh, custom_file, report
      book = Spreadsheet::Workbook.new
      sheet = book.create_worksheet name: "7501 Audit"
      counter = 0
      foreach(custom_file) do |original_row| 
        report_row = sheet.row(counter)
        copy_partial_row(original_row, report_row, [*0..7])
        if counter.zero?
          report_row.insert(8, "VFI Track - HTS")
          report_row.insert(9, "Match?")
        else
          prod_uid = original_row[2][0..7]
          report_row.insert(8, hts_hsh[prod_uid])
          check = (report_row[4].to_s == report_row[8].to_s).to_s.upcase
          report_row.insert(9, check)
        end
        counter += 1
      end
      book.write report.path
    end

    def copy_partial_row from_row, to_row, index_arr
      index_arr.each { |index| to_row.insert(index, from_row[index]) }
    end

    def prod_query prod_uid_arr
      <<-SQL
        SELECT p.unique_identifier, t.hts_1, t.hts_2, t.hts_3
        FROM products p
          INNER JOIN classifications cl ON p.id = cl.product_id
          INNER JOIN tariff_records t on cl.id = t.classification_id
          INNER JOIN countries co ON co.id = cl.country_id
        WHERE co.iso_code = "US"
          AND p.unique_identifier IN (#{prod_uid_arr.map{|uid| "\"" + uid + "\""}.join(", ")})
      SQL
    end

    def get_column custom_file, num
      col = []
      foreach(custom_file) { |row| col << row[num] }
      col.shift
      col
    end

    def send_report email, report
      subject = "Eddie Bauer 7501 Audit"
      body = "<p>Report attached.<br>--This is an automated message, please do not reply. <br> This message was generated from VFI Track</p>".html_safe
      OpenMailer.send_simple_html(email, subject, body, [report]).deliver!
    end

    def send_errors email, errors
      errors << "Unrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."  
      body = "Eddie Bauer 7501 '#{@custom_file.attached_file_name}' has finished processing.\n\n#{errors.join("\n")}"
      subject = "Eddie Bauer 7501 Audit Completed With Errors"
      OpenMailer.send_simple_html(email, subject, body).deliver!
    end

  end
end; end; end