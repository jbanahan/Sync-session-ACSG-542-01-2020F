module OpenChain; module Report; class HmDrawbackExportReport
  include OpenChain::Report::BuilderOutputReportHelper

  def run settings
    raise "An email_to setting containing an array of email addresses must be provided." unless settings['email_to'] && settings['email_to'].respond_to?(:each)

    start_date, end_date = get_date_range settings

    b = builder("csv")
    write_report_to_builder b, start_date, end_date

    write_builder_to_tempfile(b, "hm_drawback_export_#{start_date.strftime "%Y%m%d"}_#{end_date.strftime "%Y%m%d"}") do |f|
      OpenMailer.send_simple_html(settings['email_to'], "H&M Drawback Export Report", "Your H&M Drawback Export Report for #{start_date.strftime "%m/%d/%Y"} - #{end_date.strftime "%m/%d/%Y"} is attached.", [f]).deliver_now
    end
  end

  def write_report_to_builder builder, start_date, end_date
    distribute_reads do
      hm_us_importer = Company.where(system_code:'HENNE').first
      raise "H&M importer with system code 'HENNE' not found." unless hm_us_importer.present?

      sheet = builder.create_sheet "Data"
      write_header_row(builder, sheet, column_names)

      i2_line_id_set = SortedSet.new

      # The bulk of the report is run based on entries: looking up entries within a date range and then trying to
      # marry them to I2/product xref side table content.
      entries = Entry.where(customer_number:'HMCAD', entry_filed_date:start_date..end_date)
      entries.find_each(batch_size:50) do |entry|
        entry.commercial_invoices.each do |invoice|
          # VFI Track adds a suffix to the invoice number when it processes the Fenix file: lengthy invoices are split
          # into multiple containing 999 or fewer lines for CBSA compliance.  The I2 drawback files aren't aware of
          # this and have only the original, unhyphened invoice numbers.
          invoice_number = invoice.invoice_number.split('-').first

          invoice_line_hash = hash_invoice_lines_by_po_part_number invoice
          invoice_line_hash.each do |key_arr, invoice_line_arr|
            po_number, part_number = key_arr

            # Look for a matching I2 export line.
            # Invoice line part number is a 7-character part number/style.  The I2 part number value is really a SKU that
            # begins with the part number, but contains additional information.  We must use like-matching.
            # like-matching.  Between invoice/PO and part numbers, we have a unique I2 file match most of the
            # time, but it's possible multiple records will match.  That is handled below: all of the matches are
            # included in some form.
            i2_matches = HmI2DrawbackLine.where(po_number: po_number, invoice_number: invoice_number, shipment_type:"export").where("part_number like ?", "#{part_number}%")

            # At least one row should be written for every invoice line regardless of whether it can be matched up to
            # I2 and product xref records.  The drawback team will fill in the blanks.
            invoice_line_arr.each do |invoice_line|
              i2 = get_i2_line_to_use i2_matches, i2_line_id_set
              row = make_row entry, invoice, invoice_line, i2, invoice_number, hm_us_importer
              write_body_row(builder, sheet, row)
            end

            # Attach any UNUSED I2 line matches to the final invoice line, duping all entry/invoice content.
            # (Although this seems problematic, drawback confirmed they wanted dupe content.)  This is meant to handle
            # situations where there are multiple I2 records for assorted SKUs corresponding to one (or, fewer,
            # at least) invoice lines.
            i2_matches.each do |i2|
              if get_unused_i2_line(i2, i2_line_id_set)
                invoice_line = invoice_line_arr.last
                row = make_row entry, invoice, invoice_line, i2, invoice_number, hm_us_importer
                write_body_row(builder, sheet, row)
              end
            end
          end
        end
      end

      # Once we've done what we can do with entry-based content, drawback has insisted that we include the I2 file
      # content from the same date range that DID NOT match to any entry.  Rows generated in this fashion will be
      # largely empty, missing all invoice/entry content.
      all_i2_lines = HmI2DrawbackLine.where(shipment_date:start_date..end_date, shipment_type:"export")
      all_i2_lines.find_each(batch_size:500) do |i2|
        if !i2_line_id_set.include? i2.id
          row = make_row nil, nil, nil, i2, i2.invoice_number, hm_us_importer
          write_body_row(builder, sheet, row)
        end
      end
    end
  end

  private
    # Start and end dates, if not supplied, default to the start/end dates of the quarter 3 quarters back.
    # This means that the dates will cover a period that is at least 6 months ago, but before 9 months ago.  For
    # example, if this was run without date range parameters on 1/1/2018, the drawback lines converted would span dates
    # from 4/1/2017 through 6/30/2017.
    def get_date_range settings
      start_date = settings['start_date'].nil? ? nil : Date.parse(settings['start_date'])
      if start_date.nil?
        start_date = SearchCriterion.get_previous_quarter_start_date(Time.zone.now, 3)
      end
      start_date = start_date.beginning_of_day

      end_date = settings['end_date'].nil? ? nil : Date.parse(settings['end_date'])
      if end_date.nil?
        end_date = SearchCriterion.get_previous_quarter_start_date(Time.zone.now, 2) - 1.day
      end
      end_date = end_date.end_of_day

      [start_date, end_date]
    end

    # Creates a hash based on PO and part number of all the lines under an invoice.  Although PO/part number combos
    # are not really meant to be duplicated over multiple lines, sometimes they are.  Lines sharing PO/part number are
    # stored in arrays within the hash.
    def hash_invoice_lines_by_po_part_number invoice
      invoice_line_hash = {}
      invoice.commercial_invoice_lines.each do |invoice_line|
        key_arr = [invoice_line.po_number, invoice_line.part_number]
        arr = invoice_line_hash[key_arr]
        if arr.nil?
          arr = []
          invoice_line_hash[key_arr] = arr
        end
        arr << invoice_line
      end
      invoice_line_hash
    end

    # Keeps track of which I2 lines have already been matched to invoice lines on this report.
    # Method will return the first match in the provided array whose ID is not in the provided set.  That may be none:
    # all may have been used already, or the array could be empty.  If a non-nil value is returned, its ID is also
    # added to the set by this method.
    def get_i2_line_to_use i2_match_arr, i2_line_id_set
      i2 = nil
      i2_match_arr.each do |i2_match|
        i2 = get_unused_i2_line i2_match, i2_line_id_set
        break unless i2.nil?
      end
      i2
    end

    # Determines if the I2 line's ID is in the provided set.  If it isn't, the I2 line is returned, and
    # its ID is added to the set.  If it has been used on this report already, a nil value is returned.
    def get_unused_i2_line i2, i2_line_id_set
      used = true
      if !i2_line_id_set.include?(i2.id)
        used = false
        i2_line_id_set << i2.id
      end
      used ? nil : i2
    end

    def make_row entry, invoice, invoice_line, i2, invoice_number, hm_us_importer
      # If we found an I2 match, look for a matching product xref.  This match is much simpler.
      product_xref = i2 ? HmProductXref.where(sku:i2.part_number).first : nil

      tariffs = invoice_line.try(:commercial_invoice_tariffs)
      invoice_tariff = tariffs ? tariffs.first : nil

      row = []
      row << entry.try(:direct_shipment_date)
      row << (i2 && i2.shipment_date ? Date.parse(i2.shipment_date.strftime("%Y-%m-%d")) : nil)
      row << i2.try(:part_number)
      row << invoice_line.try(:part_number)
      row << product_xref.try(:color_description)
      row << product_xref.try(:size_description)
      row << i2.try(:carrier)
      row << invoice_line.try(:line_number)
      # This is the invoice number potentially containing suffix (e.g. "12345-01").
      row << invoice.try(:invoice_number)
      row << i2.try(:customer_order_reference)
      row << i2.try(:carrier_tracking_number)
      row << entry.try(:entry_number)
      row << (invoice_line ? invoice_line.po_number : i2.try(:po_number))
      # This is the suffix-less invoice number.
      row << invoice_number
      row << 'CA'
      row << invoice_line.try(:quantity)
      row << i2.try(:quantity)
      row << invoice_tariff.try(:hts_code)
      row << i2.try(:part_description)
      row << 'EA'
      row << hm_us_importer.name
      row << (tariffs && tariffs.length > 1 ? "Y" : "N")
      row << (i2 && i2.export_received ? "Y" : "N")

      row
    end

    def column_names
      ["EXPORT DATE","SHIP DATE","PART NUMBER","STYLE","COLOR DESCRIPTION","SIZE DESCRIPTION","CARRIER","LINE NUMBER",
          "REF 1 - CANADIAN COMMERCIAL INVOICE NUMBER","REF 2 - CUSTOMER ORDER REFERENCE",
          "REF 3 - CARRIER TRACKING NUMBER","REF 4 - CANADIAN ENTRY NUMBER","REF 5 - SALES ORDER NUMBER",
          "REF 6 - EXPORT INVOICE NUMBER","DESTINATION COUNTRY","QUANTITY","QUANTITY (I2)","SCHEDULE B CODE",
          "DESCRIPTION","UOM","IMPORTER ID","MULTIPLE TARIFF?","EXPORT RECEIVED?"]
    end

end; end; end