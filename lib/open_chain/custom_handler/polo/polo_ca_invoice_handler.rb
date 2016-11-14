require 'open_chain/xl_client'
require 'digest/sha1'

class PoloParserError < StandardError; end

module OpenChain; module CustomHandler; module Polo
  class PoloCaInvoiceHandler

    RL_CA_FACTORY_STORE_TAX_ID ||= "806167003RM0002"

    def initialize custom_file
      @custom_file = custom_file
    end

    # Required for custom file processing
    def process user
      errors = nil
      begin
        parse @custom_file.attached.path
      rescue PoloParserError => e
        subject = "Errors were encountered while processing '#{@custom_file.attached_file_name}'"
        body = e.message
        OpenChain::S3.download_to_tempfile(@custom_file.bucket, @custom_file.path, original_filename: @custom_file.attached_file_name) do |f|
          OpenMailer.send_simple_html(user.email, subject, body, f).deliver
        end
      rescue
        error = "Errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
        raise
      ensure
        body = "RL Canada Invoice File '#{@custom_file.attached_file_name}' has finished processing."
        body += "\n#{error}" if error
        user.messages.create(:subject=>"RL Canada Invoice File Processing Complete", :body=>body)
      end
    end

    def can_view?(user)
      user.company.master?
    end

    def parse s3_path, suppress_fenix_send = false
      # The standard spreadsheet gem will not read the RL invoice files, I'm not entirely sure why, but if you try and open
      # the file the CPU spikes to 100% and the system attempts to endlessly allocate memory and eventually crashes the ruby process.
      # Luckily, the XLServer / POI library seems to be able to handle the files.
      xl = xl_client s3_path

      invoice, po_number = parse_header xl

      # We want the last line number because there's some summary information after it
      # that we'll want to grab.  Because we're using xl client it's much more efficient reading
      # down the page progressively than trying to find the last lines as part of the header
      # parsing method (due to every xl_client call being an http request)
      summary_start_row = parse_details xl, invoice, po_number

      parse_summary xl, summary_start_row, invoice

      unless suppress_fenix_send
        OpenChain::CustomHandler::FenixNdInvoiceGenerator.generate invoice
      end
    end

    private

      def xl_client s3_path
        OpenChain::XLClient.new s3_path
      end

      def parse_header xl
        importer = Company.where(:fenix_customer_number => RL_CA_FACTORY_STORE_TAX_ID, :importer => true).first
        unless importer
          raise PoloParserError.new "No Importer company exists with Tax ID #{RL_CA_FACTORY_STORE_TAX_ID}.  This company must exist before RL CA invoices can be created against it."
        end

        header_row = nil
        counter = -1
        begin
          row = get_row_values(xl, (counter+= 1)).map(&:to_s)
          # Look for a row w/ Date and Ref # in there somewhere
          date_found = row.find {|v| v =~ /DATE/i }
          ref_found = row.find {|v| v =~ /BOL\s*#/i}

          if date_found && ref_found
            header_row = row
            break
          end
        end while header_row.nil? && counter < 20

        raise PoloParserError.new("Unable to find header starting row.") if header_row.nil?

        # The row immediately after the header is the row that has the invoice date, invoice # and po #
        column_map = header_column_map header_row

        invoice_row = get_row_values(xl, (counter += 1))

        invoice = CommercialInvoice.new invoice_number: v(column_map, invoice_row, "BOL#"), importer: importer
        invoice.invoice_date = date_value(v(column_map, invoice_row, "DATE"))
        po_number = v(column_map, invoice_row, "PO #")

        # Find the "country of export" and Terms of Sale / Currency cells
        begin
          row = get_row_values(xl, (counter += 1))

          if row[0].to_s =~ /Country of Export/i
            invoice.country_origin_code = get_cell_value xl, 0, (counter += 1)
          end

          if row[0].to_s =~ /Terms of Sale/i
            invoice.currency = parse_currency get_cell_value(xl, 0, (counter += 1))
          end
        end while (invoice.country_origin_code.nil? || invoice.currency.nil?) && counter < 30

        [invoice, po_number]
      end

      def parse_summary xl, summary_start_row, invoice
        # We could sum the invoice lines to come up with the value, but we should probably take the value
        # listed in the spreadsheet.  That way if there are any issues at all w/ bad data in the individual lines, we at least
        # may have the correct value in the total

        # Find the last row with a numeric value in it, that should be the invoice value
        invoice.invoice_value = get_row_values(xl, summary_start_row).reverse.find {|v| v.to_i > 0 }

        # Now find where the quantity and the cartons are offset from the summary start
        counter = summary_start_row
        carton_row = nil
        weight_row = nil
        begin
          row = get_row_values(xl, (counter += 1))
          carton_row = row if row[1].to_s.upcase.include?("CARTONS")
          weight_row = row if row[1].to_s.upcase.include?("WEIGHT")
        end while (carton_row.nil? || weight_row.nil?) && counter < (summary_start_row + 20)

        if carton_row
          invoice.total_quantity = carton_row[0]
          invoice.total_quantity_uom = "CTNS"
        end

        if weight_row
          invoice.gross_weight = weight_row[0]
        end
      end

      def find_invoice invoice_number, importer
        # Need the select here to work around ActiveRecord markings records as readonly if you use a join clause
        # (Even though in this case we know that the commercial invoice data is all going to be loaded)
        invoice = CommercialInvoice.select("commercial_invoices.*").where(:invoice_number => invoice_number).
                  joins(:importer).where(:companies => {:fenix_customer_number => importer.fenix_customer_number}).first

        if invoice
          invoice.commercial_invoice_lines.destroy_all
        else
          invoice = CommercialInvoice.new :invoice_number => invoice_number, :importer => importer
        end

        invoice
      end

      def get_cell_value xl, column, row
        xl.get_cell 0, row, column
      end

      def get_row_values xl, row
        xl.get_row_values 0, row
      end

      def date_value value
        unless value.nil? || value.acts_like?(:time) || value.acts_like?(:date)
          # We'll assume at this point we can try and parse a date out of whatever value we got.
          Date.strptime(value.to_s, "%m/%d/%Y") rescue value = nil
        end
        value
      end

      def parse_currency value
        # They're putting the shipping terms and currency in the same cell, should be separated by a /
        # Find the last / and everything after that is the currency
        unless value.nil?
          # Basically, take everything after the last slash in the string
          last_index = value.reverse.index("/")
          if last_index && last_index > 0
            value = value[(last_index * -1)..-1].strip
          else
            value = ""
          end
        end
        value
      end

      def parse_details xl, invoice, po_number
        # Find details columns (since RL is sending different formats of the invoice now)
        column_map = nil
        detail_header_row = nil
        (15..25).each do |row|
          mapping = detail_column_map(get_row_values(xl, row))
          if mapping["STYLE"] && mapping["HTS"] && mapping["DESCRIPTION"]
            detail_header_row = row
            column_map = mapping
            break
          end
        end

        if detail_header_row.nil?
          raise PoloParserError.new 'Unable to locate where invoice detail lines begin.  Detail lines should begin after a row with columns named "Style Number", "HTS", and "Description of Goods".'
        end

        # All this while condition does is get the next row value, increment the row counter and validate that we haven't
        # hit the totals line (ie. we're past the details section)
        row = nil
        rollup = {}

        while true do
          row = get_row_values(xl, (detail_header_row += 1))

          # Catch runaway processing just in case the indicators we're using to find the summary section
          # fail (.ie invoice is changed).  5000 is way more lines than we could possibly handle on an invoice (even rolled up)
          if row.nil? || totals_line?(row) || detail_header_row > 5000
            break
          end

          if valid_detail_line? row
            keys = generate_rollup_keys(column_map, row)
            key = ''

            keys.each do |rollup_key|
              next if rollup[rollup_key].blank?
              key = rollup_key
            end

            # We are defaulting to the unit price listed, if no key is found.
            key = keys[1] if key.blank?

            if rollup[key].blank?
              line = invoice.commercial_invoice_lines.build
              tariff = line.commercial_invoice_tariffs.build

              line.po_number = po_number
              line.part_number = v(column_map, row, "STYLE")
              line.country_origin_code = v(column_map, row, "COUNTRY")
              tariff.hts_code = hts_value(v(column_map, row, "HTS"))
              tariff.tariff_description = v(column_map, row, "DESCRIPTION")
              line.quantity = decimal_value(v(column_map, row, "QTY"))
              line.unit_price = decimal_value(v(column_map, row, "UNIT"))
              rollup[key] = line
            else
              rollup[key].quantity += decimal_value(v(column_map, row, "QTY"))

              # Let's check if the unit_price on the line is less than the current price
              unit_price = decimal_value(v(column_map, row, "UNIT"))
              rollup[key].unit_price = unit_price if rollup[key].unit_price < unit_price
            end
          end
        end

        raise PoloParserError.new "Invoice contains more than 999 rows." unless rollup.length < 1000
        # The detail_header_row now indicates the totals row, which is what we want to return
        # so that we can parse some information out of the summary section of the invoice
        detail_header_row
      end

      def totals_line? values
        # We're looking for a row that has a Units label in it as the sole label of a column and the next column has a numeric value in it
        index = values.index {|v| v.to_s.strip =~ /^UNITS\s*[:punct:]*$/i}
        !index.nil? && index > 0 && values[index + 1].to_i > 0
      end

      def valid_detail_line? values
        # Look for non-blank values in at least 5 of the 10 cells.
        values.select{|v| !v.blank?}.length > 4
      end

      def decimal_value val
        # If the value is a string, then parse it as a big decimal
        if val.is_a? String
          val = BigDecimal.new val
        end

        val
      end

      def hts_value val
        hts = nil
        unless val.nil?
          # val can possibly not be a string -> 1234.34
          val = val.to_s.gsub(".", "")

          # These invoices apparently will sometimes have HTS values like "Set Item 1: 1234567890 / Set Item 2: 9876543210"
          # In that case we don't actually want to pull the value in since we don't which hts should actually be used
          hts_codes = val.scan /(\d{5,})/
          if hts_codes.length == 1
            hts = hts_codes[0][0]
          end
        end

        hts
      end

      def generate_rollup_keys(column_map, row)
        keys = []
        ['-0.01', '0.0', '0.01'].each do |val|
          key = "#{v(column_map, row, "STYLE")} ~~~ "
          key << "#{v(column_map, row, "COUNTRY")} ~~~ "
          key << "#{hts_value(v(column_map, row, "HTS"))} ~~~ "
          key << "#{decimal_value(v(column_map, row, "UNIT")) + BigDecimal(val)}"
          keys << key
        end
        keys
      end

      def detail_column_map header_row
        create_mapping ["STYLE", "COUNTRY", "HTS", "DESCRIPTION", "QTY", "UNIT"], header_row
      end

      def create_mapping values, header_row
        mapping = {}
        row = header_row.map {|v| v.to_s.upcase }
        values.each do |header|
          index = row.index {|v| v.include?(header)}
          mapping[header] = index if index
        end

        mapping
      end

      def v mapping, row, header
        index = mapping[header]
        index ? row[index] : nil
      end

      def header_column_map header_row
        create_mapping ["DATE", "BOL#", "PO #"], header_row
      end
  end
end; end; end