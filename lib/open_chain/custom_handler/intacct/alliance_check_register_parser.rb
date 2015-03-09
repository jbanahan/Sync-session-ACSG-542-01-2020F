require 'open_chain/s3'
require 'open_chain/custom_handler/intacct/alliance_day_end_handler'
require 'digest'

module OpenChain; module CustomHandler; module Intacct; class AllianceCheckRegisterParser
  include ActionView::Helpers::NumberHelper

  def self.process_from_s3 bucket, key, opts={}
    # The first thing to do is save this file off as a CustomFile
    # Then we want to check if there's a AP/AR Invoice Report file from today that has not been processed.
    # If so, then kick off the daily process
    check_register = nil
    integration = User.integration
    filename = File.basename(key)
    unique_file = nil
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
        xref = DataCrossReference.where(cross_reference_type: DataCrossReference::ALLIANCE_CHECK_REPORT_CHECKSUM, key: md5).where("created_at > ? ", Time.zone.now - 1.month).first

        check_register = CustomFile.new(:file_type=>self.name,:uploaded_by=>integration)
        check_register.attached = tmp
        if xref
          check_register.start_at = Time.zone.now
          check_register.finish_at = Time.zone.now
          check_register.error_at = Time.zone.now
          check_register.error_message = "Another file named #{xref.value} has already been received with this information."
        else
          unique_file = true
        end
        check_register.save!
        DataCrossReference.create!(cross_reference_type: DataCrossReference::ALLIANCE_CHECK_REPORT_CHECKSUM, key: md5, value: filename) if unique_file
      end
    end

    if unique_file
      Lock.acquire(Lock::ALLIANCE_DAY_END_PROCESS) do
        day_end_file = CustomFile.where(file_type: OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser.name, uploaded_by_id: integration, start_at: nil).where('created_at >= ?', Time.zone.now.to_date).first

        if day_end_file
          OpenChain::CustomHandler::Intacct::AllianceDayEndHandler.delay.process_delayed check_register.id, day_end_file.id, nil
        end
      end
    end
  end

  def extract_check_info fin
    check_info = {}
    buffered_checks = []
    header_found = false
    valid_file_format = nil
    fin.each_line do |line|
      next if line.blank?

      if valid_file_format.nil?
        valid_file_format = valid_format? line
      end

      # Look for a line that starts with ----------, this signifies that the next lines will have check data
      if line.starts_with? "----------"
        header_found = true
      elsif header_found 
        # Check information can be extracted on lines where the first 10 characters have the check number in them (.ie a string of digits)
        if line[0, 10].strip =~ /^\d+$/
          local_check_info = {}
          local_check_info[:check_number] = line[0, 10].strip
          local_check_info[:vendor_number] = line[11, 10].strip
          local_check_info[:invoice_number] = line[22, 10].strip
          local_check_info[:invoice_suffix] = line[32, 2].strip
          local_check_info[:customer_number] = line[47, 10].strip
          local_check_info[:vendor_reference] = line[72, 12].strip
          local_check_info[:check_amount] = parse_number line[85, 13].strip
          local_check_info[:check_date] = parse_date line[99, 10]


          buffered_checks << local_check_info
        elsif line =~ /(\d+) Checks? for Bank (\d+) Totaling\s+([\d\.,-]+)/i
          bank_number = $2
          per_bank_check_count = $1.to_i
          per_bank_check_sum = parse_number $3
          # Strip leading zeros - done after the others since a regex is used which clears out the capture vars
          bank_number = bank_number.gsub(/^0+/, "").to_i.to_s

          buffered_checks.each do |c|
            c[:bank_number] = bank_number
          end
          
          check_info[:checks] ||= {}
          check_info[:checks][bank_number] = {check_count: per_bank_check_count, check_total: per_bank_check_sum, checks: buffered_checks}
          buffered_checks = []
          header_found = false
        elsif line =~ /\s+\*+\s Grand Total \s\*+\s+Record Count:\s+(\d+)\s+([\d,\.-]+)/i
          check_info[:total_check_count] = $1.to_i
          check_info[:total_check_amount] = parse_number $2
        end
      end
    end

    check_info
  end

  def validate_check_info check_info
    # The file was bad if we didn't find any of the grand totals
    raise "No Check Register Record Count found." if check_info[:total_check_count].blank? || check_info[:total_check_count] < 0 
    raise "No Check Register Grand Total amount found." if check_info[:total_check_amount].blank?

    # Validate the total # of checks was valid and the total amount found was valid
    running_sum = BigDecimal.new "0"
    check_count = 0

    errors = []
    check_info[:checks].each do |bank_no, bank_check_info|
      local_check_count = bank_check_info[:checks].length
      check_count += local_check_count
      local_sum = bank_check_info[:checks].inject(BigDecimal.new("0")) {|sum, info| sum += info[:check_amount]}
      running_sum += local_sum

      errors << "Expected #{bank_check_info[:check_count]} #{"check".pluralize(bank_check_info[:check_count])} for Bank #{bank_no.to_s.rjust(2, "0")}.  Found #{local_check_count} #{"check".pluralize(local_check_count)}." unless local_check_count == bank_check_info[:check_count]
      errors << "Expected Check Total Amount of #{number_to_currency bank_check_info[:check_total]} for Bank #{bank_no.to_s.rjust(2, "0")}.  Found #{number_to_currency local_sum}." unless local_sum == bank_check_info[:check_total]
    end

    # Validate the grand totals too.
    errors << "Expected #{check_info[:total_check_count]} #{"check".pluralize(check_info[:total_check_count])} to be in the register file.  Found #{check_count} #{"check".pluralize(check_count)}." unless check_count == check_info[:total_check_count]
    errors << "Expected Grand Total of #{number_to_currency check_info[:total_check_amount]} to be in the register file.  Found #{number_to_currency running_sum}." unless check_info[:total_check_amount] == running_sum

    return errors
  end

  def create_and_request_check check_info, sql_proxy_client
    errors = []
    check = nil
    export = nil
    suffix = check_info[:invoice_suffix].blank? ? nil : check_info[:invoice_suffix].strip
    Lock.acquire(Lock::INTACCT_DETAILS_PARSER) do

      # There's error cases where the check number appears on multiple lines...this happens when the check print queue is screwed up and isn't resolved
      # correctly by the users.  This results in check numbers being physically printed twice - for different files or the same file twice.  In this case, the check
      # registry will have BOTH check lines in it and will sum So, if we only log one of the check numbers listed (by only using the check number/bank/check_date/check_type) 
      # then when the amounts are totalled at the end of the day end processed against the registry amount, the amounts will be (correctly) off and kick out an
      # error on the exception report forcing the user to validate the amounts.  This is what we want.
      check = IntacctCheck.where(check_number: check_info[:check_number], check_date: check_info[:check_date], bank_number: check_info[:bank_number], voided: (check_info[:check_amount].to_f) < 0.0).first_or_create!
      if check.intacct_upload_date.nil? && check.intacct_key.nil?
        export = check.intacct_alliance_export
        if export.nil?
          export = IntacctAllianceExport.create! file_number: check_info[:invoice_number], suffix: suffix, check_number: check_info[:check_number], 
                                                  ap_total: check_info[:check_amount], export_type: IntacctAllianceExport::EXPORT_TYPE_CHECK, intacct_checks: [check]
        end
      else
        check = nil
      end
    end

    if check
      Lock.with_lock_retry(check) do
        Lock.with_lock_retry(export) do
          check.amount = check_info[:check_amount]
          check.file_number = check_info[:invoice_number]
          check.suffix = suffix
          check.customer_number = check_info[:customer_number]
          check.bill_number = (check_info[:invoice_number].strip + check_info[:invoice_suffix].strip)
          check.vendor_number = check_info[:vendor_number]
          check.vendor_reference = check_info[:vendor_reference]
          # This is the prepaid GL Account, it lets us track how much is floating out there in check payments associated with invoices
          check.gl_account = '2021'

          # The cash GL account to use for the check transaction record is xref'ed to the bank's name and not the bank number
          bank_name = DataCrossReference.find_alliance_bank_number check.bank_number
          check.bank_cash_gl_account = DataCrossReference.find_intacct_bank_gl_cash_account bank_name

          export.data_requested_date = Time.zone.now
          export.data_received_date = nil
          export.customer_number = check.customer_number
          export.invoice_date = check.check_date
          export.check_number = check.check_number
          export.save!

          check.intacct_alliance_export = export
          check.save!
        end
      end

      # The amount thing here is a DelayedJob workaround...the version we're using doesn't serialize BigDecimal correctly.
      # Instead it ends up in the delayed_job process as a float, which ends up being inexact when attempting to do any sort of multiplication
      # Just do the amount change to Alliance format here instead
      sql_proxy_client.delay.request_check_details check.file_number, check.check_number, check.check_date, check.bank_number, check.amount.to_s
    else
      errors << "Check # #{check_info[:check_number]} has already been sent to Intacct."
    end

    [check, errors]
  end


  private

    def parse_number value
      # Strip commas and dollar signs
      # Move hyphens (negative amounts) to front, BigDecimal constructor will handle it correctly then
      if value =~ /-$/
        value = ("-" + value[0..-2])
      end

      BigDecimal.new value.to_s.gsub /[,$]/, ""
    end

    def parse_date value
      Date.strptime value, "%m/%d/%Y"
    end

    def valid_format? first_file_line
      if first_file_line =~ /APMRGREG-D0-06\/22\/09/
        return true
      else
        raise "Attempted to parse an Alliance Check Register file that is not the correct format. Expected to find 'APMRGREG-D0-06/22/09' on the first non-blank line of the file."
      end
    end

end; end; end; end;