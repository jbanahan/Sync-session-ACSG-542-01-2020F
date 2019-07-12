require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/custom_file_csv_excel_parser'

# Populates the H&M Receipt Line table, which maps SKUs to receipt date and a couple of values ultimately needed
# for duty calc.
module OpenChain; module CustomHandler; module Hm; class HmReceiptFileParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser
  include Rails.application.routes.url_helpers

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.valid_file? filename
    ['.XLS','.XLSX', '.CSV'].include? File.extname(filename.upcase)
  end

  def can_view? user
    user.in_group?('hm_receipt_file_upload')
  end

  def process user
    errors = []

    # Skip the first line of the file (header).
    begin
      foreach(@custom_file, skip_headers:true, skip_blank_lines:true) {|row, row_number|
        begin
          row_errors = parse_row row
          if row_errors.length > 0
            errors << "Line #{row_number + 1}: #{row_errors.join("  ")}"
          end
        rescue => e
          errors << "Line #{row_number + 1}: #{e.message}"
        end
      }
    ensure
      body = "H&M Receipt File processing for '#{@custom_file.attached_file_name}' is complete."
      subject = "File Processing Complete"
      unless errors.blank?
        body += "\n\nAn email has been sent to members of the H&M Receipt File Parser Errors mailing list detailing issues encountered during processing of #{errors.length} line#{errors.length > 1 ? "s":""}."
        subject += " With Errors"
        send_error_email errors
      end
      user.messages.create(:subject=>subject, :body=>body)
    end
  end

  # Should not be excluding older dates when processing.
  def max_valid_date_age_years
    500
  end

  private
    def parse_row row
      errors = []

      delivery_date = date_value row[1]
      if !delivery_date
        errors << "Delivery Date is required and must be in mm/dd/yyyy format."
      end

      order_number = text_value row[3]
      errors << "Order Number is required." unless !order_number.blank?

      sku = text_value row[6]
      errors << "SKU is required." unless !sku.blank?

      if errors.length == 0
        rec = HmReceiptLine.where(order_number:order_number, sku:sku, delivery_date:delivery_date).first_or_create
        rec.location_code = text_value row[0]
        rec.ecc_variant_code = text_value row[2]
        rec.production_country = text_value row[4]
        rec.quantity = integer_value row[5]
        rec.season = text_value row[7]
        rec.save!
      end

      errors
    end

    def send_error_email errors
      mailing_list = MailingList.where(system_code:'HmReceiptFileParserErrors').first
      raise "H&M Receipt File Parser Errors mailing list not configured." unless mailing_list
      subject = "H&M Import Drawback Data: Errors/missing values"
      body = "Drawback data could not be generated for some file lines. See the attached document for a full list of issues.<br><br>Please contact VFI Track Support at support@vandegriftinc.com with any questions.".html_safe

      attachments = []
      begin
        attachments << make_error_file(errors)
        OpenMailer.send_simple_html([mailing_list], subject, body, attachments).deliver_now
      ensure
        attachments.each(&:close!)
      end
    end

    def make_error_file errors
      f = Tempfile.new(['errors','.txt'])
      errors.each do |err|
        f.puts err
      end
      f.flush
      Attachment.add_original_filename_method f, "errors.txt"
      f
    end

end;end;end;end