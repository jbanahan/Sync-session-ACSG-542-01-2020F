require 'open_chain/xl_client'
require 'digest/sha1'
require 'open_chain/custom_handler/polo/polo_ca_fenix_nd_invoice_generator'

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
      invoice.save!

      unless suppress_fenix_send
        OpenChain::CustomHandler::Polo::PoloCaFenixNdInvoiceGenerator.generate invoice.id
      end
    end

    private

      def xl_client s3_path
        OpenChain::XLClient.new s3_path
      end

      def parse_header xl
        importer = Company.where(:fenix_customer_number => RL_CA_FACTORY_STORE_TAX_ID, :importer => true).first
        unless importer
          raise "No Importer company exists with Tax ID #{RL_CA_FACTORY_STORE_TAX_ID}.  This company must exist before RL CA invoices can be created against it."
        end

        header_row = nil
        counter = -1
        begin
          row = get_row_values(xl, (counter+= 1)).map(&:to_s)
          # Look for a row w/ Date and Ref # in there somewhere
          date_found = row.find {|v| v =~ /DATE/i }
          ref_found = row.find {|v| v =~ /REF\s*#/i}

          if date_found && ref_found
            header_row = row
            break
          end
        end while header_row.nil? && counter < 20


        raise "Unable to find header starting row." if header_row.nil?

        # The row immediately after the header is the row that has the invoice date, invoice # and po #
        column_map = header_column_map header_row

        invoice_row = get_row_values(xl, (counter += 1))

        invoice = find_invoice v(column_map, invoice_row, "REF#"), importer
        invoice.invoice_date = date_value(v(column_map, invoice_row, "DATE"))
        po_number = v(column_map, invoice_row, "CA P.O.")

        # Find the "country of export" and Terms of Sale / Currency cells
        begin 
          row = get_row_values(xl, (counter += 1))

          if row[0].to_s =~ /Shipper \/ Exporter/i
            invoice.vendor = parse_company importer, :vendor, xl, 0, (counter += 1), "Country of Export"
          end

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

      def parse_company importer, company_type, xl, column, starting_row, hard_stop_value
        # The addresses here are an indeterminate # of lines (somewhere between 3 and 5 lines)
        # We have potentially 2 lines for the company name and 2 for the address
        # We're assuming the last line is always the city, state, postal code

        address_lines = get_address_lines xl, column, starting_row, hard_stop_value
        address = parse_address_lines address_lines

        # Short of creating a new company/address for every invoice, the easiest thing to probably do here
        # is combine all the pieces of the address hash together into a SHA-1 hash and use that as the address identifier (address.name)
        # and look up any existing company with that address associated with the importer account.

        # Even though we're not using any real address information any longer, I'd like to keep using the address.name storing the digest
        # value since there's a system-wide unique constraint on the system code value that I don't think needs to be enforced here.
        address_info = ""
        [:name, :name_2].each {|key| address_info += address[key] unless address[key].blank?}

        # Strip all non-word chars from the address since we don't really want a stray comma or space causing us to build a new address
        digest = Digest::SHA1.base64digest address_info.gsub(/\W/, "")

        # Make sure we're finding companies that are linked to the importer record
        company = Company.where(company_type => true).
                  joins("INNER JOIN linked_companies ON companies.id = linked_companies.child_id AND linked_companies.parent_id = #{importer.id}").
                  joins(:addresses).where(:addresses => {:name => digest}).
                  first

        if company.nil? && !address[:name].blank?
          company = Company.new :name => address[:name], :name_2 => address[:name_2]
          company.vendor = company_type == :vendor
          company.consignee = company_type == :consignee
          # We need to remove all non-Address attributes from the hash
          a = company.addresses.build :name=>digest
          company.save!
          importer.linked_companies << company
        end

        company
      end

      def get_address_lines xl, column, starting_row, hard_stop_value
        address_lines = []
        (starting_row..(starting_row + 4)).each do |row|
          value = get_cell_value xl, column, row

          if !value.blank?
            if value.include? hard_stop_value
              break
            else
              address_lines << value.strip
            end
          end
        end

        address_lines
      end

      def parse_address_lines address_lines
        address = {}
        if address_lines.length == 3
          address = {:name => address_lines[0], :line_1 => address_lines[1], :city_state_zip => address_lines[2]}
        elsif address_lines.length == 4
          # We have either a 2 line name or a 2 line street address
          address = {:name => address_lines[0], :city_state_zip => address_lines[3]}

          # Find which of these two lines starts with a number and we'll assume that's a street number and is address line 1
          index = address_lines[1..2].find_index {|line| line =~ /^\s*\d/}
          if index
            # account for looking for the street address at index 1 of main address line array
            index += 1

            address[:line_1] = address_lines[index]
            # If the address is directly above the last line, we know there's only a single address line
            if (index + 1) == (address_lines.length - 1)
              address[:name_2] = address_lines[index - 1]
            else
              # We have two address lines
              address[:line_2] = address_lines[index - 1]
            end
          end
        elsif address_lines.length == 5
          address = {:name => address_lines[0], :name_2=> address_lines[1], :line_1 => address_lines[2], :line_2 => address_lines[3], :city_state_zip => address_lines[4]}
        end

        # At this point, we don't care about the address information...we'll just include the company name and forget about the rest
        # to avoid the pain of having to write a full-blown address parsing routine and all the corner case handling that entails.
        address.delete :line_1
        address.delete :line_2
        address.delete :city_state_zip
        address
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
          raise 'Unable to locate where invoice detail lines begin.  Detail lines should begin after a row with columns named "Style Number", "HTS", and "Description of Goods".'
        end

        # All this while condition does is get the next row value, increment the row counter and validate that we haven't 
        # hit the totals line (ie. we're past the details section)
        row = nil
        while true do
          row = get_row_values(xl, (detail_header_row += 1))

          # Catch runaway processing just in case the indicators we're using to find the summary section
          # fail (.ie invoice is changed).  5000 is way more lines than we could possibly handle on an invoice (even rolled up)
          if row.nil? || totals_line?(row) || detail_header_row > 5000
            break
          end

          if valid_detail_line? row
            line = invoice.commercial_invoice_lines.build
            tariff = line.commercial_invoice_tariffs.build

            line.po_number = po_number
            line.part_number = v(column_map, row, "STYLE")
            line.country_origin_code = v(column_map, row, "COUNTRY")
            tariff.hts_code = hts_value(v(column_map, row, "HTS"))
            tariff.tariff_description = v(column_map, row, "DESCRIPTION")
            line.quantity = decimal_value(v(column_map, row, "QTY"))
            line.unit_price = decimal_value(v(column_map, row, "UNIT"))
          end
        end

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
        create_mapping ["DATE", "REF#", "CA P.O."], header_row
      end
  end
end; end; end