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
      HmCiLoadParser.new nil
    else
      StandardCiLoadParser.new nil
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

    def kewill_generator
      OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
    end

    # At some point, we may want to move these classes out to their own files (perhaps in a new ci_load subdirectory)
    class StandardCiLoadParser < CiLoadHandler

      def invalid_row? row
        row[0].to_s.blank? || row[1].to_s.blank? || row[2].to_s.blank?
      end

      def file_number_invoice_number_columns
        {file_number: 0, invoice_number: 2}
      end

      def parse_entry_header row
        OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new text_value(row[0]), text_value(row[1]), []
      end

      def parse_invoice_header entry, row
        OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new text_value(row[2]), date_value(row[3]), []
      end

      def parse_invoice_line entry, invoice, row
        l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
        l.country_of_origin = text_value row[4]
        l.part_number = text_value row[5]
        l.pieces = decimal_value(row[6])
        l.mid = text_value row[7]
        l.hts = text_value row[8].to_s.gsub(".", "")
        l.cotton_fee_flag = text_value row[9]
        l.foreign_value = decimal_value(row[10])
        l.quantity_1 = decimal_value(row[11])
        l.quantity_2 = decimal_value(row[12])
        l.gross_weight = decimal_value(row[13])
        l.po_number = text_value(row[14])
        l.cartons = decimal_value(row[15])
        l.first_sale = decimal_value row[16]

        mmv_ndc = decimal_value(row[17])
        if mmv_ndc.nonzero?
          # So, pperations was / is using this field for two different purposes (WTF)...when the value
          # is negative they're expecting it to go to the non-dutiable field in kewill, when it's positive
          # it should go to the add to make amount.
          if mmv_ndc > 0
            l.add_to_make_amount = mmv_ndc
          else
            l.non_dutiable_amount = (mmv_ndc * -1)
          end
        end

        l.department = decimal_value(row[18])
        l.spi = text_value(row[19])
        l.buyer_customer_number = text_value(row[20])
        l.seller_mid = text_value(row[21])
        l.spi2 = text_value(row[22])
        
        l
      end
    end

    # At some point, we may want to move these classes out to their own files (perhaps in a new ci_load subdirectory)
    class HmCiLoadParser < CiLoadHandler

      def invalid_row? row
        row[0].to_s.blank? || row[2].to_s.blank?
      end

      def file_number_invoice_number_columns
        {file_number: 0, invoice_number: 2}
      end

      def parse_entry_header row
        OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new text_value(row[0]), "HENNE", []
      end

      def parse_invoice_header entry, row
        inv = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new text_value(row[2]), nil, []
        inv.non_dutiable_amount = (decimal_value(row[4]).presence || 0).abs
        if inv.non_dutiable_amount
          inv.non_dutiable_amount = inv.non_dutiable_amount.abs
        end
        inv.add_to_make_amount = decimal_value(row[5])

        inv
      end

      def parse_invoice_line entry, invoice, row
        l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
        l.foreign_value = decimal_value(row[3])
        l.hts = text_value row[7].to_s.gsub(".", "")
        l.country_of_origin = text_value row[8]
        l.quantity_1 = decimal_value(row[9])
        l.quantity_2 = decimal_value(row[10])
        l.cartons = decimal_value(row[11])
        l.gross_weight = decimal_value(row[12])
        l.mid = text_value row[13]
        l.part_number = text_value row[14]
        l.pieces = decimal_value(row[15])
        l.buyer_customer_number = text_value(row[16])
        l.seller_mid = text_value(row[17])

        l
      end
    end

end; end; end;
