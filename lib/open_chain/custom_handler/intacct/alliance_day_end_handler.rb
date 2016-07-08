require 'open_chain/s3'
require 'open_chain/custom_handler/intacct/alliance_check_register_parser'
require 'open_chain/custom_handler/intacct/alliance_day_end_ar_ap_parser'
require 'open_chain/custom_handler/intacct/intacct_invoice_details_parser'
require 'open_chain/custom_handler/intacct/intacct_data_pusher'
require 'open_chain/kewill_sql_proxy_client'
require 'spreadsheet'

module OpenChain; module CustomHandler; module Intacct; class AllianceDayEndHandler
  include ActionView::Helpers::NumberHelper

  def self.process_delayed check_register_file_id, invoice_file_id, user_id
    user = user_id ? User.find(user_id) : nil
    check_register_file = CustomFile.find check_register_file_id
    invoice_file = CustomFile.find invoice_file_id

    p = self.new check_register_file, invoice_file
    p.process user
  end

  def initialize check_register_file, invoice_file
    @check_register = check_register_file
    @invoices = invoice_file
  end

  def self.can_view? user
    IntacctErrorsController.allowed_user?(user)
  end

  def process user = nil
    users = []
    if user.nil?
      users = User.joins(:groups).where(groups: {system_code: IntacctErrorsController::VFI_ACCOUNTING_USERS}).all
      raise "No users found to send Day End information to." if users.size == 0
    else
      users << user
    end

    # Read Check Info
    start = Time.zone.now
    @check_register.update_attributes! start_at: start
    @invoices.update_attributes! start_at: start

    check_parser = OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.new
    check_errors, check_info = read_check_register @check_register, check_parser

    # Read all payable / receivable information
    invoice_parser = OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser.new
    invoice_errors, invoice_info = read_invoices @invoices, invoice_parser

    # If error, abort...send errors to Luca, Isabelle..one tab for check errors, one tab for ar/ap errors.
    if check_errors.size > 0 || invoice_errors.size > 0
      # Send errors to the users to notify for day end stuff
      send_parser_errors @check_register.attached_file_name, check_errors, @invoices.attached_file_name, invoice_errors, users.map(&:email), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.to_date
      subject = "Day End Processing Complete With Errors"
      message = "The day end files could not be processed.  A separate report containing the errors will be mailed to you."
      send_messages_to_users users, subject, message
    else
      proxy_client = OpenChain::KewillSqlProxyClient
      check_results = create_checks(check_info, check_parser, proxy_client)

      check_sum = BigDecimal.new "0"
      check_results[:exports].each do |ex|
        check_sum += ex.ap_total
      end

      invoice_results = create_invoices(invoice_info, invoice_parser, proxy_client)
      ap_sum = BigDecimal.new "0"
      ar_sum = BigDecimal.new "0"
      invoice_results[:exports].each do |ex|
        ap_sum += ex.ap_total
        ar_sum += ex.ar_total
      end

      wait_for_export_updates check_results[:exports] + invoice_results[:exports]
      wait_for_dimension_uploads

      errors = validate_export_amounts_received start, check_sum, ar_sum, ap_sum

      error_count = 0
      if errors.try(:size).to_i > 0
        error_count = errors[:checks].try(:length).to_i + errors[:invoices].try(:length).to_i

        send_parser_errors @check_register.attached_file_name, errors[:checks], @invoices.attached_file_name, errors[:invoices], users.map(&:email), ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.to_date
      else
        upload_intacct_data OpenChain::CustomHandler::Intacct::IntacctDataPusher.new

        # The exception report returns the number of errors found while uploading so we can determine in the user message if there were upload
        # errors or not
        error_count = run_exception_report OpenChain::Report::IntacctExceptionReport.new, users.map(&:email)
      end

      subject = "Day End Processing Complete"
      message = "Day End Processing has completed.<br>AR Total: #{number_to_currency(ar_sum)}<br>AP Total: #{number_to_currency(ap_sum)}<br>Check Total: #{number_to_currency(check_sum)}"

      if error_count > 0
        subject += " With Errors"
        message += "<br>#{error_count} errors were encountered.  A separate report containing errors will be mailed to you."
      end
      send_messages_to_users users, subject, message
    end

    nil
  ensure
    end_time = Time.zone.now
    @check_register.update_attributes! finish_at: end_time
    @invoices.update_attributes! finish_at: end_time
  end

  def read_check_register check_file, parser
    check_info = nil
    OpenChain::S3.download_to_tempfile(OpenChain::S3.bucket_name(:production), check_file.attached.path) do |io|
      check_info = parser.extract_check_info io
    end

    errors = parser.validate_check_info check_info
    
    [errors, check_info]
  end

  def read_invoices invoice_file, parser
    invoice_info = nil
    OpenChain::S3.download_to_tempfile(OpenChain::S3.bucket_name(:production), invoice_file.attached.path) do |io|
      invoice_info = parser.extract_invoices io
    end

    errors = parser.validate_invoice_data invoice_info

    # Strip the ar/ap grand total keys (don't want them any longer)
    invoice_info.delete :ar_grand_total
    invoice_info.delete :ap_grand_total
    
    [errors, invoice_info]
  end

  def send_parser_errors check_filename, check_errors, invoice_filename, invoice_errors, email_to, date
    wb = generate_errors_xls check_errors, invoice_errors
    filename = "Day End Errors #{date.strftime("%Y-%m-%d")}"
    Tempfile.open([filename, '.xls']) do |f|
      wb.write f
      f.rewind
      Attachment.add_original_filename_method f
      f.original_filename = (filename + ".xls")
      body = "Errors were encountered while attempting to read the Alliance Day end files.<br>"
      if check_errors && check_errors.length > 0
        body += "Found #{check_errors.length} #{"error".pluralize(check_errors.length)} in the Check Register File #{check_filename}.<br>"
      end
      if invoice_errors && invoice_errors.length > 0
        body += "Found #{invoice_errors.length} #{"error".pluralize(invoice_errors.length)} in the Invoice File #{invoice_filename}.<br>"
      end

      body += "Please see the attached report for all error messages and resolve the issues before resending the files."

      OpenMailer.send_simple_html(email_to, "Alliance Day End Errors", body.html_safe, [f]).deliver!
    end
  end

  def create_checks check_info, check_parser, sql_proxy_client
    # Create all the check "stub" information, then kick off delayed sql proxy client
    # instances to retrieve the rest of the data necessary for upload
    all_errors = []
    exports = []
    check_info[:checks].each do |bank_no, bank_check_info|
      bank_check_info[:checks].each do |info|
        check, errors = check_parser.create_and_request_check info, sql_proxy_client
        
        if check
          exports << check.intacct_alliance_export
        end

        all_errors.push *errors
      end
    end

    {errors: all_errors, exports: exports}
  end

  def all_exports_finished? export_ids
     IntacctAllianceExport.where(id: export_ids).where("data_received_date IS NULL").count == 0
  end

  def wait_for_export_updates exports, sleep_time = 10, max_wait_time = 3600
    export_ids = exports.map &:id

    # Give the data at most an hour to come across...it shouldn't take anywhere near this amount of time, but be generous.
    max_loop_count = max_wait_time / sleep_time
    count = 0
    while ((count +=1) <= max_loop_count)
      # Check is moved to another method primarily for testing purposes
      break if all_exports_finished?(export_ids)
      sleep(sleep_time)
    end

    raise Timeout::Error if count > max_loop_count
  end

  def wait_for_dimension_uploads sleep_time = 1, max_wait_time = 3600
    # We need to make sure all dimension uploads clear before kicking off 
    # the actual intacct uploads, otherwise, there's a distinct chance of an upload
    # failing because the file number isn't in Intacct yet.
    
    # Give the data at most an hour to come across...it shouldn't take anywhere near this amount of time, but be generous.
    max_loop_count = max_wait_time / sleep_time
    count = 0
    while ((count +=1) <= max_loop_count)
      break if all_dimension_uploads_finished?
      sleep sleep_time
    end
    raise Timeout::Error if count > max_loop_count
  end

  def all_dimension_uploads_finished?
    return true if Rails.env.development?
    
    Delayed::Job.where("handler like ? ", "%method_name: :#{OpenChain::CustomHandler::Intacct::IntacctClient.method(:async_send_dimension).name}%").count == 0
  end

  def create_invoices invoice_info, parser, sql_proxy_client
    all_errors = []
    exports = []

    invoice_info.each_pair do |invoice_number, invoice_info|
      export, errors = parser.create_and_request_invoice invoice_info, sql_proxy_client

      all_errors.push *errors
      exports << export if export
    end

    {errors: all_errors, exports: exports}
  end

  def upload_intacct_data pusher
    # NEVER run this unless we're in production..we don't have a test environment for Intacct
    # so make sure we don't accidently upload to intacct at all
    if Rails.env.production?
      pusher.run ['vfc', 'lmd']
    end
  end

  def run_exception_report report, email_to
    report.run ['vfc', 'lmd'], email_to
  end

  private 

    def generate_errors_xls check_errors, invoice_errors
      wb = Spreadsheet::Workbook.new
      if check_errors
        widths = []
        sheet = XlsMaker.create_sheet wb, "Check Register Errors", ["Error"]
        check_errors.each_with_index {|e, x| XlsMaker.add_body_row(sheet, (x+1), [e], widths)}
      end

      if invoice_errors
        widths = []
        sheet = XlsMaker.create_sheet wb, "Invoice Errors", ["Error"]
        invoice_errors.each_with_index {|e, x| XlsMaker.add_body_row(sheet, (x+1), [e], widths)}
      end

      wb
    end

    def send_messages_to_users users, subject, message
      users.each do |u|
        u.messages.create! subject: subject, body: message
      end
    end

    def validate_export_amounts_received start_time, check_total, ar_total, ap_total
      errors = {}
      db_start_time = start_time.to_s(:db)

      qry = <<-QRY
SELECT SUM(c.amount)
FROM intacct_alliance_exports e
INNER JOIN intacct_checks c on e.id = c.intacct_alliance_export_id
WHERE e.export_type = '#{IntacctAllianceExport::EXPORT_TYPE_CHECK}' and e.data_received_date >= '#{db_start_time}' and c.intacct_upload_date IS NULL
QRY
      amount = ActiveRecord::Base::connection.execute(qry).first[0]
      errors[:checks] = ["Expected to retrieve #{number_to_currency(check_total)} in Check data from Alliance.  Received #{number_to_currency(amount ? amount : 0)} instead."] if amount != check_total

      # AR Total - This is the sum of all the AR lines received by our invoicing process
      # The bit in the middle w/ the VFI/LMD stuff is excluding any receivables for the LMD company that
      # represent the internal billing process we do for Freight Shipments.
      qry = <<-QRY
SELECT SUM(CASE 
WHEN r.receivable_type like '%#{IntacctReceivable::CREDIT_INVOICE_TYPE}%'  THEN l.amount * -1
ELSE l.amount
END) FROM intacct_alliance_exports e 
INNER JOIN intacct_receivables r on r.intacct_alliance_export_id = e.id AND (r.company = '#{OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser::VFI_COMPANY_CODE}' OR (r.company = '#{OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser::LMD_COMPANY_CODE}' and r.customer_number <> '#{OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser::LMD_VFI_CUSTOMER_CODE}'))
INNER JOIN intacct_receivable_lines l on r.id = l.intacct_receivable_id
WHERE e.export_type = '#{IntacctAllianceExport::EXPORT_TYPE_INVOICE}' AND e.data_received_date >= '#{db_start_time}'  and r.intacct_upload_date IS NULL
QRY
      amount = ActiveRecord::Base::connection.execute(qry).first[0]
      errors[:invoices] = []
      errors[:invoices] << "Expected to retrieve #{number_to_currency(ar_total)} in AR lines from Alliance.  Received #{number_to_currency(amount ? amount : 0)} instead." if amount != ar_total

      # The bit in the middle below excludes the payables generated from VFI to LMD as part of the inter-company
      # freight billing process.
      qry = <<-QRY
SELECT SUM(l.amount)
FROM intacct_alliance_exports e
INNER JOIN intacct_payables p on p.intacct_alliance_export_id = e.id and (p.company = '#{OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser::LMD_COMPANY_CODE}' or (p.company = '#{OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser::VFI_COMPANY_CODE}' and p.vendor_number <> '#{OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser::VFI_LMD_VENDOR_CODE}'))
INNER JOIN intacct_payable_lines l on p.id = l.intacct_payable_id
WHERE e.export_type = '#{IntacctAllianceExport::EXPORT_TYPE_INVOICE}' and e.data_received_date > '#{db_start_time}'  and p.intacct_upload_date IS NULL
QRY
      amount = ActiveRecord::Base::connection.execute(qry).first[0]
      errors[:invoices] << "Expected to retrieve #{number_to_currency(ap_total)} in AP lines from Alliance.  Received #{number_to_currency(amount ? amount : 0)} instead." if amount != ap_total

      errors.delete(:invoices) if errors[:invoices].length == 0
      errors
    end

end; end; end; end;
