require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'
require 'open_chain/s3'
require 'open_chain/xl_client'
require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler; class CiLoadHandler
  include CustomFileCsvExcelParser

  def initialize file
    @custom_file = file
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("alliance") && user.company.master?
  end

  def self.valid_file? file_name
    [".csv", ".xls", ".xlsx"].include? File.extname(file_name.to_s.downcase)
  end

  def can_view? user
    self.class.can_view? user
  end

  def process user
    errors = []
    results = {}
    begin
      results = parse_and_send @custom_file
    rescue OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError => e
      errors << e.message
    rescue OpenChain::CustomHandler::CustomFileCsvExcelParser::NoFileReaderError => e
      errors << e.message
      errors << "Please ensure the file is an Excel or CSV file and the filename ends with .xls, .xlsx or .csv."
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
    # We may want to eventually retain the header so we can allow for "fluid" layouts based on the header names, or 
    # use the header row to determine what layout to use, but for now, we can skip it
    rows = foreach(custom_file, skip_headers: true, skip_blank_lines: true)

    parser = file_parser custom_file

    # Remove any row the parser considers invalid (we'll report the number of bad lines back to the user)
    bad_rows, rows = rows.partition {|row| parser.invalid_row? row }
    file_column = parser.file_number_invoice_number_columns[:file_number]
    invoice_column = parser.file_number_invoice_number_columns[:invoice_number]

    entry_files = {}
    rows.each do |row|
      data = preprocess_row row

      # This should be getting verified by the invalid_row? in the parser implementation, but it's important
      # enough that we should also be handling it here too
      if data[file_column].blank? || data[invoice_column].blank?
        bad_rows << row
        next
      end

      file_number = text_value(data[file_column]).to_s
      entry = entry_files[file_number]

      if entry.nil?
        entry = parser.parse_entry_header row
        entry_files[file_number] = entry
      end

      invoice_number = text_value(data[invoice_column]).to_s
      invoice = entry.invoices.find {|i| i.invoice_number == invoice_number}
      if invoice.nil?
        invoice = parser.parse_invoice_header entry, row
        entry.invoices << invoice
      end

      invoice.invoice_lines << parser.parse_invoice_line(entry, invoice, row)
    end

    files = entry_files.values
    {bad_row_count: bad_rows.size, generated_file_numbers: files.map(&:file_number), entries: files }
  end

  def file_parser custom_file
    case custom_file.attached_file_name
    when /^HMCI\./i
      OpenChain::CustomHandler::Vandegrift::HmCiLoadParser.new nil
    when /^FTZ-/i
      OpenChain::CustomHandler::Vandegrift::FtzCiLoadParser.new nil
    else
      OpenChain::CustomHandler::Vandegrift::StandardCiLoadParser.new nil
    end
  end

  private

    def preprocess_row row
      # change blank values to nil and strip whitespace from all String values
      row.map {|v| v.to_s.blank? ? nil : (v.is_a?(String) ? v.strip : v)}
    end

    def date_value d
      # This is basically just copying what was allowed to be put as a date in the legacy VB program.
      # Kinda convoluted...but we should probably keep what used to be allowed.
      v = nil
      if d.respond_to?(:strftime)
        v = d.strftime "%Y%m%d"
      else
        # In case there's been a floating-point conversion, strip decimals and anything after
        s = d.to_s.gsub(/\..+/, "")
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
        if !MasterSetup.test_env? && (date.year - Time.zone.now.year).abs > 2 
          date = nil
        end
      end

      date
    rescue
      nil
    end

    def kewill_generator
      OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
    end

end; end; end;

require_dependency 'open_chain/custom_handler/vandegrift/hm_ci_load_parser'
require_dependency 'open_chain/custom_handler/vandegrift/standard_ci_load_parser'
require_dependency 'open_chain/custom_handler/vandegrift/ftz_ci_load_parser'
