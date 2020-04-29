require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler; module Generic; class IsfLateFlagFileParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.valid_file? filename
    ['.XLS', '.XLSX', '.CSV'].include? File.extname(filename.upcase)
  end

  def can_view? user
    user.company.broker? && MasterSetup.get.custom_feature?('ISF Late Filing Report')
  end

  def process user
    errors = []
    begin
      errors = process_file @custom_file
    rescue => e
      errors << "The following fatal error was encountered: #{e.message}"
    ensure
      body = "ISF Late Flag processing for file '#{@custom_file.attached_file_name}' is complete."
      subject = "File Processing Complete"
      unless errors.blank?
        body += "\n\n#{errors.join("\n")}"
        subject += " With Errors"
      end
      user.messages.create(:subject=>subject, :body=>body)
    end
    nil
  end

  private
    def process_file custom_file
      errors = []
      filename = custom_file.attached_file_name
      row_counter = 1
      # Source file is an Excel spreadsheet.  We're dealing with it remotely, on a server equipped to deal with Excel crud.
      # Here, thanks to the handy 'foreach' method below, the parser doesn't need to be aware of the original data format.
      foreach(custom_file) {|row|
        begin
          # Skip the first 8 lines of the file.  It's a multi-line header.
          # Also skip blank lines.  (We can't exclude these in 'foreach' because there could be blanks in the header, and
          # that is being excluded via line count.)
          parse_row(row) unless row_counter < 9 || blank_row?(row)
          row_counter += 1
        rescue => e
          isf_transaction_number = row[3]
          errors << "Failed to process Transaction Number '#{isf_transaction_number}' due to the following error: '#{e.message}'"
        end
      }
      errors
    end

    def parse_row row
      isf_transaction_number = row[3]
      raise "Transaction Number is required for all lines." unless !isf_transaction_number.to_s.empty?

      # Find the matching security filing record by transaction number.  Note that the transaction numbers in the file
      # may contain a hyphen.  Database values have this stripped out.
      isf = SecurityFiling.where(transaction_number: isf_transaction_number.tr('-', '')).first
      raise "ISF transaction could not be found." unless isf

      # Technically, a filing is considered late by customs if the first file date is less than 24 hours before
      # departure date.  The US government wants to know about what's going to be shipping BEFORE it ships...at least
      # 24 hours before.  (There are two other ISF fields that must be sent to customs at least 24 hours before arrival
      # (the "2" portion of "10+2").  These are probably not considered for the purposes of this file.)
      # We can assume anything in this file is LATE, and don't need to do any date comparison.
      # Therefore, the late_filing flag is always set to true below.
      isf.late_filing = true
      # Customs generates these timestamps in US eastern.
      isf.us_customs_first_file_date = parse_eastern_us_time_zone_date row[6]
      # Per SOW 1284, departure date has a "default time value".  For lack of anything better, and since it looks like
      # times are being included with these dates, we've opted to assume US eastern as well.
      isf.vessel_departure_date = parse_eastern_us_time_zone_date row[7]
      isf.save!
      # At the time of this program's creation (July 2017), there was no snapshotting for the ISF module.
    end

    # Deals with a date string that doesn't have time zone explicitly stated, and effectively assigns the parsed value
    # to a time zone.
    #
    # date_string is expected to be in the pattern mm/dd/yy hh:mm:ss p, like "08/29/97 06:06:06 AM"
    def parse_eastern_us_time_zone_date date_string
      DateTime.strptime("#{date_string} #{ActiveSupport::TimeZone["America/New_York"].now.strftime("%z")}", "%m/%d/%y %H:%M:%S %p %z")
    end

end; end; end; end