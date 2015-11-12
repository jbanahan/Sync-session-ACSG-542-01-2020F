require 'open_chain/custom_handler/kewill_commercial_invoice_generator'
require 'open_chain/s3'
require 'open_chain/xl_client'

module OpenChain; module CustomHandler; class CiLoadHandler

  def initialize file
    @custom_file = file
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("alliance") && user.company.master?
  end

  def can_view? user
    self.class.can_view? user
  end

  def process user
    errors = []
    results = {}
    begin
      results = parse_and_send @custom_file
    rescue
      errors << "Unrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
      raise
    ensure
      body = "CI Load File '#{@custom_file.attached_file_name}' has finished processing."

      if results[:generated_file_numbers] && results[:generated_file_numbers].size > 0
        body += "\nThe following file numbers are being transferred to Kewill Customs. They will be available shortly."
        body += "\nFile Numbers: #{results[:generated_file_numbers].join(", ")}"
      end

      if results[:bad_row_count] && results[:bad_row_count] > 0
        body += "\nAll rows in the CI Load files must have values in the File #, Customer and Invoice # columns. #{results[:bad_row_count]} #{"row".pluralize(results[:bad_row_count])} were missing one or more values in these columns and were skipped."
      end

      subject = "CI Load Processing Complete"
      if !errors.blank?  || (results[:bad_row_count] && results[:bad_row_count] > 0)
        subject += " With Errors"

        body += "\n\n#{errors.join("\n")}" unless errors.blank?
      end

      user.messages.create(:subject=>subject, :body=>body)
    end
    nil
  end

  def parse_and_send custom_file
    results = parse custom_file 
    kewill_generator.generate_and_send(results[:entries]) unless results[:entries].size == 0
    results 
  end

  def parse custom_file
    parser = file_parser custom_file
    # Return all rows, stripping any rows that have no values in them
    rows = parser.parse_file(custom_file).select {|r| !r.blank? && !r.find {|v| !v.blank? }.nil? }

    # Strip row 0, it's the headers
    rows.shift

    # Remove any row without a File #, Customer # and Invoice # (we'll report the number of bad lines back to the user)
    bad_rows, rows = rows.partition {|row| row[0].to_s.blank? || row[1].to_s.blank? || row[2].to_s.blank? }

    entry_files = {}

    rows.each do |row|
      data = preprocess_row row

      file_number = string_value(data[0])
      entry = entry_files[file_number]

      if entry.nil?
        entry = OpenChain::CustomHandler::KewillCommercialInvoiceGenerator::CiLoadEntry.new file_number, string_value(data[1]), []
        entry_files[file_number] = entry
      end

      invoice_number = string_value(data[2])
      invoice = entry.invoices.find {|i| i.invoice_number == invoice_number}
      if invoice.nil?
        invoice = OpenChain::CustomHandler::KewillCommercialInvoiceGenerator::CiLoadInvoice.new invoice_number, date_value(data[3]), []
        entry.invoices << invoice
      end

      invoice.invoice_lines << parse_invoice_line_values(row)
    end

    files = entry_files.values
    {bad_row_count: bad_rows.size, generated_file_numbers: files.map(&:file_number), entries: files }
  end

  def file_parser custom_file
    extension = File.extname(custom_file.attached_file_name).downcase
    case extension
    when ".csv", ".txt"
      return CsvParser.new
    when ".xls", ".xlsx"
      return ExcelParser.new
    else
      raise "No CI Upload processor exists for #{extension} file types."
    end
  end

  private

    def parse_invoice_line_values row
      l = OpenChain::CustomHandler::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
      l.country_of_origin = string_value row[4]
      l.part_number = string_value row[5]
      l.gross_weight = decimal_value(row[13])
      l.pieces = decimal_value(row[6])
      l.hts = string_value row[8].to_s.gsub(".", "")
      l.foreign_value = decimal_value(row[10])
      l.quantity_1 = decimal_value(row[11])
      l.quantity_2 = decimal_value(row[12])
      l.po_number = string_value(row[14])
      l.first_sale = decimal_value row[16]
      l.department = decimal_value(row[18])
      l.spi = string_value(row[19])
      l.ndc_mmv = decimal_value(row[17])
      l.cotton_fee_flag = string_value row[9]
      l.mid = string_value row[7]
      l.cartons = decimal_value(row[15])

      l
    end

    def preprocess_row row
      # change blank values to nil and strip whitespace from all String values
      row.map {|v| v.to_s.blank? ? nil : (v.is_a?(String) ? v.strip : v)}
    end

    def decimal_value d
      # use space character set since that handles all UTF-8 whitespace too, not just ascii 33 (space bar)
      d.blank? ? nil : BigDecimal(d.to_s.gsub(/\$[[:space:]]/, ""))
    end

    def date_value d
      # This is basically just copying what was allowed to be put as a date in the legacy VB program.
      # Kinda convoluted...but we should probably keep what used to be allowed.
      v = nil
      if d.respond_to?(:strftime)
        v = d.strftime "%Y%m%d"
      else
        s = d.to_s
        if s =~ /^(\d{1,4})[^\d](\d{1,2})[^\d](\d{1,4})$/
          first = $1
          second = $2
          last = $3

          # If the first digit section is more than 2 digits then we'll assume it's the year (.ie YYYY-mm-dd)
          # otherwise, we'll assume the first digits are the month (.ie mm-dd-YY or mm-dd-YYYY)
          if first.length > 2
            v = "#{first.rjust(4, '0')}#{second.rjust(2, '0')}#{last.rjust(2, '0')}"
          else
            last = (last.length == 2) ? (last.to_i + 2000).to_s : last.rjust(4, '0')

            v = "#{last}#{first.rjust(2, '0')}#{second.rjust(2, '0')}"
          end
          
        else
          # I don't know why anyone would key a date as 150201 (YYmmdd), but the old VB code allowed this
          # so I'm handling it too.
          if s.length == 6
            v = "#{2000 + s[0, 2].to_i}#{s[2, 2]}#{s[4,2]}"
          elsif s.length == 8
            if s[0,2] == "20"
              v = s
            else
              v = "#{s[4,4]}#{s[0, 2]}#{s[2, 2]}"
            end
          end
        end
      end

      # Sanity check...only allow keying years within 2 years from now
      date = nil
      if v
        date = Time.zone.parse(v).to_date
        if (date.year - Time.zone.now.year).abs > 2 
          date = nil
        end
      end

      date
    rescue
      nil
    end

    def string_value d
      OpenChain::XLClient.string_value d
    end

    def kewill_generator
      OpenChain::CustomHandler::KewillCommercialInvoiceGenerator.new
    end

    class CsvParser

      def parse_file custom_file, parser_options = {}
        rows = []
        OpenChain::S3.download_to_tempfile(custom_file.bucket, custom_file.path) do |file|
          CSV.foreach(file, parser_options) do |row|
            rows << row
          end
        end
        rows
      end
    end


    class ExcelParser

      def parse_file custom_file, parser_options = {}
        client = xl_client custom_file.path
        client.all_row_values
      end

      def xl_client s3_path
        OpenChain::XLClient.new s3_path
      end
    end

end; end; end;