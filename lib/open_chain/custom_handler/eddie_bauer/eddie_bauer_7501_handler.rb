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
      (MasterSetup.get.system_code == 'www-vfitrack-net' || Rails.env.development?) && user.view_products? && 
        (user.company.master? || user.company.alliance_customer_number == 'EDDIE')
    end

    def create_and_send_report email, custom_file
      errors = []
      begin
        create_and_send_report! email, custom_file
      rescue => e
        errors << "Failed to process 7501 due to the following error: '#{e.message}'."
        e.log_me ["Failed to process 7501. Custom File ID: #{@custom_file.id}. Message: #{e.message}"]
      end
      errors
    end

    def create_and_send_report! email, custom_file
      if  [".xls", ".xlsx", ".csv"].include? File.extname(custom_file.path).downcase
        file_contents = foreach custom_file
        hts_hsh = collect_hts file_contents
        Tempfile.open(["eb_7501_audit", ".xls"]) do |report|
          perform_audit hts_hsh, file_contents, report
          send_report email, report
        end
      else
        raise "No CI Upload processor exists for #{File.extname(custom_file.path).downcase} file types."
      end
    end

    def collect_hts file_contents
      prod_uids = get_column(file_contents, 2).map{ |n| n[0..7] }.uniq
      extract_hts prod_uids
    end

    def extract_hts prod_uids
      prod_nums = {}
      Product.connection.exec_query(prod_query prod_uids).each { |row| prod_nums[row["unique_identifier"]] = row["hts_1"].to_s }
      prod_nums
    end

    def perform_audit hts_hsh, file_contents, report
      header = file_contents.first.concat ["VFI Track - HTS", "Match?"]
      book, sheet = XlsMaker.create_workbook_and_sheet "7501 Audit", header
      row_num = 1
      file_contents.drop(1).each do |original_row| 
        original_row[8] = hts_hsh[original_row[2][0..7]]
        original_row[4] = text_value(original_row[4])
        original_row[9] = (original_row[4] == original_row[8]).to_s.upcase
        XlsMaker.add_body_row sheet, row_num, original_row
        row_num += 1
      end
      book.write report.path
    end

    def prod_query prod_uid_arr
      <<-SQL
        SELECT p.unique_identifier, t.hts_1
        FROM products p
          INNER JOIN classifications cl ON p.id = cl.product_id
          INNER JOIN tariff_records t on cl.id = t.classification_id
          INNER JOIN countries co ON co.id = cl.country_id
        WHERE co.iso_code = "US"
          AND p.unique_identifier IN (#{prod_uid_arr.map{|uid| ActiveRecord::Base.sanitize uid}.join(", ")})
      SQL
    end

    def get_column file_contents, num
      col = []
      file_contents.each { |row| col << row[num] }
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