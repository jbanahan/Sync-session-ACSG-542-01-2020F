module OpenChain; module CustomHandler; module Intacct; class AllianceCheckRegisterParser
  include ActionView::Helpers::NumberHelper

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
        elsif line =~ /(\d+) Checks? for Bank (\d+) Totaling\s+([\d\.,]+)/i
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
        elsif line =~ /\s+\*+\s Grand Total \s\*+\s+Record Count:\s+(\d+)\s+([\d,\.]+)/i
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

    # The first thing we need to check is if there is an invoice already in the system for this check that has been uploaded to intacct..
    # If so, it means the check was issued AFTER the invoice and it must be manually entered into Intacct.
    bill_number = check_info[:invoice_number].strip + check_info[:invoice_suffix].strip

    invoice = IntacctPayable.where(bill_number: bill_number, vendor_number: check_info[:vendor_number]).where("intacct_upload_date IS NOT NULL").where("intacct_key IS NOT NULL").first
    if invoice
      errors << "An invoice has already been filed in Intacct for File # #{bill_number}.  Check # #{check_info[:check_number]} must be filed manually in Intacct."
    else
      check = nil
      export = nil
      Lock.acquire(Lock::INTACCT_DETAILS_PARSER) do
        suffix = check_info[:invoice_suffix].blank? ? nil : check_info[:invoice_suffix].strip
        check = IntacctCheck.where(file_number: check_info[:invoice_number], suffix: suffix, check_number: check_info[:check_number], check_date: check_info[:check_date], bank_number: check_info[:bank_number]).first_or_create!
        if check.intacct_upload_date.nil? && check.intacct_key.nil?
          export = IntacctAllianceExport.where(file_number: check_info[:invoice_number], suffix: suffix, check_number: check_info[:check_number], export_type: IntacctAllianceExport::EXPORT_TYPE_CHECK).first_or_create!
        else
          check = nil
        end
      end

      if check
        Lock.with_lock_retry(check) do
          Lock.with_lock_retry(export) do
            check.customer_number = check_info[:customer_number]
            check.bill_number = bill_number
            check.vendor_number = check_info[:vendor_number]
            check.vendor_reference = check_info[:vendor_reference]
            check.amount = check_info[:check_amount]
            # This is the prepaid GL Account, it lets us track how much is floating out there in check payments associated with invoices
            check.gl_account = '2021'
            check.bank_cash_gl_account = DataCrossReference.find_intacct_bank_gl_cash_account check.bank_number

            export.data_requested_date = Time.zone.now
            export.data_received_date = nil
            export.ap_total = check.amount
            export.customer_number = check.customer_number
            export.invoice_date = check.check_date
            export.check_number = check.check_number
            export.save!

            check.intacct_alliance_export = export
            check.save!
          end
        end

        sql_proxy_client.delay.request_check_details check.file_number, check.check_number, check.check_date, check.bank_number
      else
        errors << "Check # #{check_info[:check_number]} has already been sent to Intacct."
      end
    end

    [check, errors]
  end


  private

    def parse_number value
      # Strip commas and dollar signs
      BigDecimal.new value.to_s.gsub /[,$]/, ""
    end

    def parse_date value
      Date.strptime value, "%m/%d/%Y"
    end

    def valid_format? first_file_line
      if first_file_line =~ /APMRGREG-D0-06\/22\/09/
        return true
      else
        raise "Attempted to parse an Alliance Check Register file that is not the correct format. Expected to find 'APMRGREG-D0-06/22/09' on the first line, but did not."
      end
    end

end; end; end; end;