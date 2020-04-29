module OpenChain; module Report; class HmDrawbackImportReport
  include OpenChain::Report::BuilderOutputReportHelper

  def run settings
    raise "An email_to setting containing an array of email addresses must be provided." unless settings['email_to'] && settings['email_to'].respond_to?(:each)

    start_date, end_date = get_date_range settings

    b = builder("csv")
    write_report_to_builder b, start_date, end_date

    write_builder_to_tempfile(b, "hm_drawback_import_#{start_date.strftime "%Y%m%d"}_#{end_date.strftime "%Y%m%d"}") do |f|
      OpenMailer.send_simple_html(settings['email_to'], "H&M Drawback Import Report", "Your H&M Drawback Import Report for #{start_date.strftime "%m/%d/%Y"} - #{end_date.strftime "%m/%d/%Y"} is attached.", [f]).deliver_now
    end
  end

  def write_report_to_builder builder, start_date, end_date
    distribute_reads do
      sheet = builder.create_sheet "Data"
      write_header_row(builder, sheet, column_names)

      receipt_line_id_set = SortedSet.new

      # The bulk of the report is run based on entries: looking up entries within a date range and then trying to
      # marry them to receipt file/product xref side table content.
      entries = Entry.where(customer_number:'HENNE', entry_filed_date:start_date..end_date)
      entries.find_each(batch_size:50) do |entry|
        entry.commercial_invoices.each do |invoice|
          invoice_line_hash = hash_invoice_lines_by_part_number invoice
          invoice_line_hash.each do |part_number, invoice_line_arr|
            # Look for matching receipt file lines.
            # Invoice line part number is a 7-character part number/style.  The receipt file part number value is
            # really a SKU that begins with the part number, but contains additional information.  We must use
            # like-matching.  Between invoice/PO and part numbers, we have a unique receipt file match most of the
            # time, but it's possible multiple records will match.  That is handled below: all of the matches are
            # included in some form.
            receipt_matches = HmReceiptLine.where(order_number: invoice.invoice_number).where("sku like ?", "#{part_number}%")

            # At least one row should be written for every invoice line regardless of whether it can be matched up to
            # receipt file and product xref records.  The drawback team will fill in the blanks.
            invoice_line_arr.each do |invoice_line|
              receipt_line = get_receipt_line_to_use receipt_matches, receipt_line_id_set
              row = make_row entry, invoice, invoice_line, receipt_line
              write_body_row(builder, sheet, row)
            end

            # Attach any UNUSED receipt line matches to the final invoice line, duping all entry/invoice content.
            # (Although this seems problematic, drawback confirmed they wanted dupe content.)  This is meant to handle
            # situations where there are multiple receipt records for assorted SKUs corresponding to one (or, fewer,
            # at least) invoice lines.
            receipt_matches.each do |receipt_line|
              if get_unused_receipt_line(receipt_line, receipt_line_id_set)
                invoice_line = invoice_line_arr.last
                row = make_row entry, invoice, invoice_line, receipt_line
                write_body_row(builder, sheet, row)
              end
            end
          end
        end
      end

      # Once we've done what we can do with entry-based content, drawback has insisted that we include the receipt file
      # content from the same date range that DID NOT match to any entry.  Rows generated in this fashion will be
      # largely empty, missing all invoice/entry content.
      all_receipt_lines = HmReceiptLine.where(delivery_date:start_date..end_date)
      all_receipt_lines.find_each(batch_size:500) do |receipt_line|
        if !receipt_line_id_set.include? receipt_line.id
          row = make_row nil, nil, nil, receipt_line
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

    # Creates a hash based on part number of all the lines under an invoice.  Although part number is not
    # really meant to be duplicated over multiple lines, sometimes it is.  Lines sharing a part number are
    # stored in arrays within the hash.
    def hash_invoice_lines_by_part_number invoice
      invoice_line_hash = {}
      invoice.commercial_invoice_lines.each do |invoice_line|
        arr = invoice_line_hash[invoice_line.part_number]
        if arr.nil?
          arr = []
          invoice_line_hash[invoice_line.part_number] = arr
        end
        arr << invoice_line
      end
      invoice_line_hash
    end

    # Keeps track of which receipt lines have already been matched to invoice lines on this report.
    # Method will return the first match in the provided array whose ID is not in the provided set.  That may be none:
    # all may have been used already, or the array could be empty.  If a non-nil value is returned, its ID is also
    # added to the set by this method.
    def get_receipt_line_to_use receipt_match_arr, receipt_line_id_set
      receipt_line = nil
      receipt_match_arr.each do |rl|
        receipt_line = get_unused_receipt_line rl, receipt_line_id_set
        break unless receipt_line.nil?
      end
      receipt_line
    end

    # Determines if the receipt line's ID is in the provided set.  If it isn't, the receipt line is returned, and
    # its ID is added to the set.  If it has been used on this report already, a nil value is returned.
    def get_unused_receipt_line rl, receipt_line_id_set
      used = true
      if !receipt_line_id_set.include?(rl.id)
        used = false
        receipt_line_id_set << rl.id
      end
      used ? nil : rl
    end

    def make_row entry, invoice, invoice_line, receipt_line
      # If we found a receipt line match, look for a matching product xref.  This match is simpler, using the
      # full SKU value and no like-matching.
      product_xref = receipt_line ? HmProductXref.where(sku:receipt_line.sku).first : nil

      tariffs = invoice_line.try(:commercial_invoice_tariffs)
      invoice_tariff = tariffs ? tariffs.first : nil

      row = []
      row << entry.try(:entry_number)
      row << entry.try(:import_date)
      row << receipt_line.try(:delivery_date)
      row << nil
      row << entry.try(:entry_port_code)
      row << entry.try(:total_duty)
      row << (entry.try(:total_duty).to_f + entry.try(:total_fees).to_f)
      row << (entry && entry.liquidation_date ? Date.parse(entry.liquidation_date.strftime("%Y-%m-%d")) : nil)
      row << entry.try(:entered_value)
      row << entry.try(:mpf)
      row << invoice.try(:exchange_rate)
      row << "HENNE"
      # Receipt line's order number is equivalent to invoice's invoice number.
      row << (invoice ? invoice.invoice_number : receipt_line.try(:order_number))
      # Column seems to be blank in most cases: PO number is used as invoice number.
      row << invoice_line.try(:po_number)
      row << nil
      row << invoice_line.try(:country_origin_code)
      row << invoice_line.try(:country_export_code)
      row << nil
      row << receipt_line.try(:sku)
      row << invoice_line.try(:part_number)
      row << product_xref.try(:color_description)
      row << product_xref.try(:size_description)
      row << nil
      row << invoice_tariff.try(:hts_code)
      row << (entry.try(:merchandise_description).to_s + " - " + invoice_tariff.try(:tariff_description).to_s)
      row << invoice_line.try(:unit_of_measure)
      row << "1"
      row << receipt_line.try(:quantity)
      row << invoice_line.try(:quantity)
      # This value is intentionally duped over 2 columns.  Reason unknown.
      row << invoice_line.try(:quantity)
      row << invoice_tariff.try(:classification_qty_2)
      row << invoice_line.try(:unit_price)
      row << nil
      row << nil
      row << nil
      row << invoice_tariff.try(:duty_rate)
      row << nil
      row << nil
      row << nil
      row << (invoice_tariff && invoice_tariff.duty_amount && invoice_line && invoice_line.quantity && invoice_line.quantity > 0 ? (invoice_tariff.duty_amount / invoice_line.quantity) : nil)
      row << "7"
      row << nil
      row << (['10', '11'].include?(entry.try(:transport_mode_code)) ? "Y" : nil)
      row << invoice_line.try(:customs_line_number)
      row << invoice_tariff.try(:duty_amount)
      row << invoice_tariff.try(:entered_value)
      row << invoice_tariff.try(:classification_qty_1)
      row << invoice_tariff.try(:entered_value_7501)
      row << nil
      row << nil
      row << nil
      row << nil
      row << entry.try(:total_taxes)
      row << invoice_tariff.try(:spi_primary)
      row << entry.try(:summary_line_count)
      row << (tariffs && tariffs.length > 1 ? "Y" : "N")

      row
    end

  def column_names
    ["IMPORT #", "IMPORT DATE", "RECEIVED DATE", "MFG DATE", "PORT", "TOTAL DUTY", "TOTAL DUTY, TAXES, FEES & PENALTIES",
     "LIQUIDATION DATE", "TOTAL ENTERED VALUE", "MPF", "CONVERSION", "CUSTOMER NUMBER", "REF 1 - INVOICE NUMBER",
     "REF 2 - ORDER NUMBER", "REF 3 - DEPT NO", "INVOICE LINE - COUNTRY ORIGIN CODE", "INVOICE LINE - COUNTRY EXPORT CODE",
     "CD", "SKU", "STYLE", "COLOR", "SIZE", "EXTERNAL PART", "HTS", "DESCRIPTION", "UNITS", "YIELD", "RECEIPT QTY", "QTY",
     "AVAILABLE QTY", "QTY 2", "DUTY VALUE 1", "DUTY VALUE 2", "DUTY VALUE 3", "DUTY VALUE 4", "RATE 1", "RATE 2",
     "RATE 3", "RATE 4", "DUTY EACH", "COMPUTE CODE", "STATUS", "OCEAN INDICATOR", "INVOICE LINE - CUSTOMS LINE NUMBER",
     "HTS DUTY", "HTS ENTERED VALUE", "HTS QTY", "HTS VALUE", "UNITS 2", "HTS2", "HTS3", "HTS4", "TOTAL TAXES",
     "INVOICE TARIFF - SPI - PRIMARY", "ENTRY SUMMARY LINE COUNT", "MULTIPLE TARIFF?"]
  end

end; end; end