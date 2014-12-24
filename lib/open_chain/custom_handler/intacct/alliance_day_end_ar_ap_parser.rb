require 'open_chain/s3'
require 'open_chain/custom_handler/intacct/alliance_day_end_handler'
require 'digest'

module OpenChain; module CustomHandler; module Intacct; class AllianceDayEndArApParser
  include ActionView::Helpers::NumberHelper

  def self.process_from_s3 bucket, key, opts={}
    # The first thing to do is save this file off as a CustomFile
    # Then we want to check if there's a Check Ledger file from today that has not been processed.
    # If so, then kick off the daily process
    day_end_file = nil
    integration = User.integration
    filename = File.basename(key)
    unique_file = false
    OpenChain::S3.download_to_tempfile(bucket, key, original_filename: filename) do |tmp|

      # Since the files we're getting here are really just print outs of a day end report
      # that we're pulling from an output directory in Alliance, it's very possible we'll
      # get multiple copies of the same data in the same day..which wouldn't be very good.

      # So, we'll record a checksum of the file data and see if it matches anything received recently
      # If so, we'll skip the file.
      md5 = Digest::MD5.file(tmp).hexdigest

      Lock.acquire(Lock::ALLIANCE_DAY_END_PROCESS) do
        # It's possible (though HIGHLY unlikely) that we'll get a hash collision, it's easy enough to make this
        # risk basically impossible by limiting the sample size to a month.  This just keeps us from having phantom failures
        # and then having to backtrace what's going on.
        xref = DataCrossReference.where(cross_reference_type: DataCrossReference::ALLIANCE_INVOICE_REPORT_CHECKSUM, key: md5).where("created_at > ? ", Time.zone.now - 1.month).first

        day_end_file = CustomFile.new(:file_type=>self.name,:uploaded_by=>integration)
        day_end_file.attached = tmp
        if xref
          day_end_file.start_at = Time.zone.now
          day_end_file.finish_at = Time.zone.now
          day_end_file.error_at = Time.zone.now
          day_end_file.error_message = "Another file named #{xref.value} has already been received with this information."
        else
          unique_file = true
        end
        day_end_file.save!
        DataCrossReference.create!(cross_reference_type: DataCrossReference::ALLIANCE_INVOICE_REPORT_CHECKSUM, key: md5, value: filename) if unique_file
      end
    end

    if unique_file
      Lock.acquire(Lock::ALLIANCE_DAY_END_PROCESS) do
        check_register = CustomFile.where(file_type: OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.name, uploaded_by_id: integration, start_at: nil).where('created_at >= ?', Time.zone.now.to_date).first
        if check_register
          OpenChain::CustomHandler::Intacct::AllianceDayEndHandler.delay.process_delayed check_register.id, day_end_file.id, nil
        end
      end
    end
  end

  def extract_invoices fin
    invoice_info = {}
    invoice_info[:ar_grand_total] = BigDecimal.new("0")
    invoice_info[:ap_grand_total] = BigDecimal.new("0")

    buffered_invoice_lines = []
    header_found = false
    grand_total_found = false
    valid_file_format = nil

    fin.each_line do |line|
      next if line.blank?

      if valid_file_format.nil?
        valid_file_format = valid_format? line
      end

      # Look for a line that starts with ---------- , this signifies that the next lines will have data for a single invoice
      if line.starts_with? "----------"
        header_found = true
      elsif header_found 

        # Any line that begins with numeric values in fields 0-10 is an invoice line
        if line.strip.length > 100 && line[0,10].strip =~ /^\d+$/
          # Anything w/ charge codes ending in * are for "reporting" purposes and should be skipped.
          # In Alliance parlance, they're "accounting suppressed".  
          # You generally see this for duty paid direct or freight paid direct lines.
          next if line[19, 5].strip =~ /\*$/

          invoice_line = {}
          invoice_line[:invoice_number] = line[0, 10].strip
          invoice_line[:suffix] = line[11, 2].strip
          invoice_line[:division] = line[14, 4].strip
          invoice_line[:invoice_date] = parse_date line[25, 8]
          invoice_line[:vendor] = line[34, 10].strip
          invoice_line[:vendor_reference] = line[45, 13].strip
          invoice_line[:customer_number] = line[69, 10].strip
          invoice_line[:amount] = parse_number line[80, 15]
          invoice_line[:currency] = line[96, 3]
          invoice_line[:a_r] = line[105, 3].strip
          invoice_line[:a_p] = line[115, 3].strip
          buffered_invoice_lines << invoice_line

        elsif line =~ /Inv\. Total:\s+([\d,]*(?:\.\d+-?)?)\s+A\/P Total:\s+([\d,]*(?:\.\d+-?)?)/i
          # There's some per company summartion lines that we want to skip, at which point there will be no
          # buffered invoice lines, so use that to tell if we need to save off anything
          if buffered_invoice_lines.length > 0
            # We found the total line for the current invoice being parsed.  Just extract the totals 
            # and store them off for validation later

            # The parse number uses a gsub regex, so parse these off first so we retain the capture groups
            ar_total = $1
            ap_total = $2

            invoice = {}
            invoice[:ar_total] = parse_number ar_total
            invoice[:ap_total] = parse_number ap_total
            invoice[:lines] = buffered_invoice_lines
            buffered_invoice_lines = []

            first_line = invoice[:lines].first
            invoice_info[first_line[:invoice_number] + first_line[:suffix]] = invoice

          elsif grand_total_found
            ar_total = $1
            ap_total = $2

            invoice_info[:ar_grand_total] += parse_number ar_total
            invoice_info[:ap_grand_total] += parse_number ap_total
            grand_total_found = false

            # once we hit the grand total line, we need to quit...there's more invoices listed after the grand total,
            # but they're credit invoices that have already been processed. 
            break
          end
          
          header_found = false
        elsif line =~ /\*\s*G\s*R\s*A\s*N\s*D\s*T\s*O\s*T\s*A\s*L\s*S\s*\*/i
          grand_total_found = true

        end
      end
    end

    invoice_info
  end

  def create_and_request_invoice invoice_data, sql_proxy_client
    errors = []
    export = nil
    # We're not REALLY making invoice data here..we're just storing off the data
    # from the invoice into the export, so we have the main data from the uploaded Alliance ar/ap report
    # available when parsing the query result (this is basically necessitated by Alliance bugs in their data)

    # If there are already uploaded receivables or payables w/ these file numbers, then we should not be creating.
    first_line = invoice_data[:lines].first

    invoice_number =  first_line[:invoice_number].to_s.strip + first_line[:suffix].to_s.strip
    invoice_count = IntacctReceivable.where(company: ['lmd', 'vfc'], invoice_number: invoice_number).where("intacct_upload_date IS NOT NULL").where("intacct_key IS NOT NULL").count
    bill_count = 1

    if invoice_count == 0
      bill_count = IntacctPayable.where(company: ['lmd', 'vfc'], bill_number: invoice_number).where("intacct_upload_date IS NOT NULL").where("intacct_key IS NOT NULL").count
    end

    if invoice_count > 0 || bill_count > 0
      errors << "An invoice and/or bill has already been filed in Intacct for File # #{invoice_number}."
    else
      Lock.acquire(Lock::INTACCT_DETAILS_PARSER) do 
        suffix = first_line[:suffix].blank? ? nil : first_line[:suffix].strip
        export = IntacctAllianceExport.where(file_number: first_line[:invoice_number], suffix: suffix, export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE).first_or_create!
      end

      Lock.with_lock_retry(export) do
        export.division = first_line[:division]
        export.invoice_date = first_line[:invoice_date]
        export.customer_number = first_line[:customer_number]
        export.ar_total = invoice_data[:ar_total]
        export.ap_total = invoice_data[:ap_total]
        export.data_received_date = nil
        export.data_requested_date = Time.zone.now

        export.save!
      end

      sql_proxy_client.delay.request_alliance_invoice_details export.file_number, export.suffix
    end

    [export, errors]
  end

  def validate_invoice_data all_invoice_info
      errors = []

      ar_total = BigDecimal.new "0"
      ap_total = BigDecimal.new "0"

      all_invoice_info.each_pair do |invoice_number, invoice_info|
        next unless invoice_info.respond_to?(:[])

        invoice_ar_total = BigDecimal.new "0"
        invoice_ap_total = BigDecimal.new "0"

        invoice_info[:lines].each do |line|
          invoice_ar_total += line[:amount] if line[:a_r].to_s.strip.upcase == "Y"
          invoice_ap_total += line[:amount] if line[:a_p].to_s.strip.upcase == "Y"
        end

        ar_total += invoice_ar_total
        ap_total += invoice_ap_total

        errors << "Expected A/R Amount for Invoice # #{invoice_number} to be #{number_to_currency invoice_info[:ar_total]}.  Found #{number_to_currency invoice_ar_total}." if invoice_ar_total != invoice_info[:ar_total]
        errors << "Expected A/P Amount for Invoice # #{invoice_number} to be #{number_to_currency invoice_info[:ap_total]}.  Found #{number_to_currency invoice_ap_total}." if invoice_ap_total != invoice_info[:ap_total]
      end

      errors << "Expected Grand Total A/R Amount to be #{number_to_currency all_invoice_info[:ar_grand_total]}.  Found #{number_to_currency ar_total}." if ar_total != all_invoice_info[:ar_grand_total]
      errors << "Expected Grand Total A/P Amount to be #{number_to_currency all_invoice_info[:ap_grand_total]}.  Found #{number_to_currency ap_total}." if ap_total != all_invoice_info[:ap_grand_total]

      errors
    end

  private 
    def parse_date value
      Date.strptime value, "%m/%d/%y"
    end

    def parse_number value
      # Strip commas and dollar signs
      val = value.to_s.gsub /[,$]/, ""

      # Negative amounts have trailing hyphen, move it to the front for BigDecimal's edification
      if val[-1] == "-"
        val = "-" + val[0..-2].strip
      end
      

      BigDecimal.new val
    end

    def valid_format? first_file_line
      if first_file_line =~ /DOEDTLS1-D0-09\/06\/03/
        return true
      else
        raise "Attempted to parse an Alliance Daily Billing List file that is not the correct format. Expected to find 'DOEDTLS1-D0-09/06/03' on the first line, but did not."
      end
    end

end; end; end; end;