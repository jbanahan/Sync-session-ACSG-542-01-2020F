require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/csv_excel_parser'
require 'open_chain/custom_handler/commercial_invoice_pdf_generator'
require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'
require 'open_chain/custom_handler/fenix_nd_invoice_generator'

module OpenChain; module CustomHandler; module Hm; class HmI2ShipmentParser
  extend OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::CsvExcelParser
  include ActionView::Helpers::NumberHelper

  def self.parse file, opts = {}
    if opts[:forward_to_entry_system].blank?
      opts[:forward_to_entry_system] = true
    end
    new.parse(file, forward_to_entry_system: opts[:forward_to_entry_system])
  end

  def parse file_contents, forward_to_entry_system: true
    rows = foreach(file_contents, skip_blank_lines: true)
    system = determine_system(rows.first)

    # Canadian customs requires that electronically filed PARS entries must be under 999 lines (WTF, eh?).
    # So, we need to chunk the file into groups of 999 lines for CA and then process each chunk of lines like
    # a completely separate file.
    files = split_file(system, rows)
    totals = []
    files.each_with_index do |file, x|
      totals << process_file(system, file, x + 1, forward_to_entry_system)
    end

    if system == :fenix
      generate_and_send_pars_pdf(totals)

      # Check PARS totals...
      pars_count = DataCrossReference.unused_pars_count
      if pars_count < pars_threshold
        OpenMailer.send_simple_html(["terri.bandy@purolator.com", "mdevitt@purolator.com", "Jessica.Webber@purolator.com"], "More PARS Numbers Required", "#{pars_count} PARS numbers are remaining to be used for H&M border crossings.  Please supply more to Vandegrift to ensure future crossings are not delayed.", [], cc: ["hm_ca@vandegriftinc.com", "hm_support@vandegriftinc.com"], reply_to: "hm_support@vandegriftinc.com").deliver!
      end
    end

    nil
  end

  def pars_threshold
    100
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_value_order_number, :prod_value, :class_customs_description, :prod_po_numbers]
    @cdefs
  end

  def split_file(system, rows)
    system == :fenix ? fenix_split(system, rows) : [rows]
  end

  def fenix_split(system, rows) 
    # So, we need to split the rows in the file at around 999 lines...the wrinkle is that we 
    # can't split it across PO numbers.  So, if we're at line 997 and the next PO has 4 lines..
    # we need to split the file at 997.
    all_files = []
    current_file_rows = []
    current_po_row_list = []
    current_shipment = nil
    current_po = nil

    list_swap_lambda = lambda do 
      # We have a new PO here...so we need to figure out what to do w/ the current po row list...
      # If the list can't be added to our current file rows, since it would make it too long, then create a new file
      if current_file_rows.length + current_po_row_list.length > max_fenix_invoice_length
        all_files << current_file_rows
        current_file_rows = current_po_row_list
      else
        # Append the contents of the po list to our current file list
        current_file_rows.push *current_po_row_list
      end
    end

    rows.each_with_index do |row, index|
      shipment_number = text_value(row[0]).to_s.strip

      # If the shipment number changes, that means we need to start a new file.
      if current_shipment.nil?
        current_shipment = shipment_number
      elsif current_shipment != shipment_number
        list_swap_lambda.call
        # If we have any lines in the current_file_rows...then flush them out to the file list since we need
        # a new file after the shipment number changes.
        all_files << current_file_rows if current_file_rows.length > 0
        current_po_row_list = []
        current_file_rows = []
        current_shipment = shipment_number
      end

      po = text_value(row[6]).to_s.strip

      if current_po.nil? || current_po == po
        current_po = po if current_po.nil?
      else
        list_swap_lambda.call

        # reset the current po list, since we got a new PO to deal with.
        current_po = po
        current_po_row_list = []
      end

      current_po_row_list << row

      # If we're at the last row....
      if index + 1 >= rows.length
        list_swap_lambda.call
        # If we have any lines in the current_file_rows...then flush them out to the file list
        all_files << current_file_rows if current_file_rows.length > 0
      end
    end

    all_files
  end

  def max_fenix_invoice_length
    999
  end

  class HmShipmentData
    attr_accessor :invoice_number, :pars_number, :cartons, :weight, :invoice_date
  end

  def process_file system, rows, file_counter, forward_to_entry_system
    # NOTE: the invoices we're creating here are NOT saved...we're just using the datastructure as a passthrough
    # for the Fenix / Kewill file transfers
    invoice = make_invoice(system, rows.first, file_counter)

    # The index position of the invoice line must correlate with the index of the row from the file due to how we're pulling
    # some data from the rows for the pdf and excel sheets.
    #
    # In other words, don't process the rows in any other order than what they came in from the file.
    missing_product_data = []
    rows.each do |row|
      product_values = set_invoice_line_info(system, invoice.commercial_invoice_lines.build, row)
      missing_product_data << product_values if product_values[:missing_data]
    end

    set_totals(invoice)

    if forward_to_entry_system
      if system == :fenix
        OpenChain::CustomHandler::FenixNdInvoiceGenerator.generate invoice
        # Generate the files for the carrier and send them
        generate_and_send_ca_files invoice, rows, missing_product_data
      else
        # Send to Kewill Customs
        g = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
        g.generate_and_send_invoices invoice.invoice_number, invoice, gross_weight_uom: "G"

        # Generate the files for the carrier and send them
        generate_and_send_us_files invoice, rows, missing_product_data
      end
    end

    generate_file_totals(invoice)
  end

  def determine_system first_line
    order_type = first_line[8].to_s

    case order_type.upcase
    when "ZSTO"
      :fenix
    when "ZRET"
      :kewill
    else
      raise "Invalid Order Type value found: '#{order_type}'.  Unable to determine what system to forward shipment data to."
    end
  end

  def make_invoice system, line, file_counter
    invoice = CommercialInvoice.new
    invoice.importer = importer(system)
    invoice.invoice_number = text_value(line[0])
    invoice.invoice_number += "-#{file_counter.to_s.rjust(2, "0")}" if system == :fenix
    invoice.invoice_date = line[3].blank? ? nil : Time.zone.parse(line[3])

    # If the invoice date is missing, the translation in the EDI process to an 810 fed into Fenix fails,
    # so just put a REALLY old date that sticks out as bad in there so that doesn't fail.
    if system == :fenix && invoice.invoice_date.nil?
      invoice.invoice_date = ActiveSupport::TimeZone["America/New_York"].parse "1900-01-01 00:00"
    end

    invoice.currency = "USD"
    
    invoice
  end

  def set_invoice_line_info system, i, line
    i.po_number = text_value(line[6])
    # The sku needs to be trimmed to 7 chars (We don't track color / size info for HM (which is the remaining X digits of the sku))
    i.part_number = text_value(line[9])[0..6]
    i.country_origin_code = text_value(line[12])
    i.quantity = decimal_value(line[13])
    i.customer_reference = text_value(line[19])
    # Net Weight is grams..convert to KG later...this is primarily because the gross weight tariff field is an integer
    # Round to the nearest 1 gram..The CI Load can be told to convert these to KG's, though if the amounts are small it may
    # end up coming over as 1 or 0 (depending on how the system rounds the value) since the CI Load does not support
    # decimal values in the gross weight field.
    net_weight = (decimal_value(line[16]).presence || BigDecimal("0")).round
    
    i.line_number = decimal_value(line[7]).to_i

    # 19 is the H&M Order number, which can be used to map back to an entry invoice line
    values = product_values(system, i.part_number, i.country_origin_code, text_value(line[19]))

    i.mid = values[:mid]
    i.unit_price = values[:product_value]
    i.value = (i.quantity.to_f > 0 && i.unit_price.to_f > 0) ? (i.unit_price * i.quantity) : 0

    i.commercial_invoice_tariffs.build hts_code: values[:hts], tariff_description: values[:description], gross_weight: net_weight
    
    values
  end

  def set_totals invoice
    totals = Hash.new {|h, k| h[k] = BigDecimal("0") }
    invoice.commercial_invoice_lines.each do |line|
      line.commercial_invoice_tariffs.each do |tar|
        totals[:gross_weight] += tar.gross_weight if tar.gross_weight
      end
    end
    # gross weight is now in grams...divide it by 1000 to get KG's and round to the nearest KG
    invoice.gross_weight = (totals[:gross_weight] / BigDecimal("1000")).round

    if invoice.gross_weight.nil? || invoice.gross_weight.to_f == 0
      # Never show that the weight is zero, just round it to one if it is.  The zero
      # has to do with the converting from grams to KG's.  This may happen in a case where the file has 1000 lines
      # and is split at 999 and the 1 line shipment has a weight < .5 KG.  Weight isn't THAT important, so we just
      # don't want to have the sheet say zero on it (since every product has some sort of weight.)
      invoice.gross_weight = 1
    end
  end

  def generate_file_totals invoice
    data = HmShipmentData.new
    data.invoice_number = invoice.invoice_number
    data.invoice_date = invoice.invoice_date
    data.pars_number = DataCrossReference.find_and_mark_next_unused_hm_pars_number
    data.weight = invoice.gross_weight

    # For every unique PO number, count it as a single carton...for the time being, since cartons,
    # are not on the I2...we just have to guestimate the carton count.
    po_numbers = Set.new

    invoice.commercial_invoice_lines.each do |line|
      po_numbers << line.po_number unless line.po_number.blank?
    end

    data.cartons = po_numbers.size

    data
  end

  def file_reader file
    csv_reader StringIO.new(file), col_sep: ";"
  end

  def product_importer
    @product_importer ||= Company.importers.where(system_code: "HENNE").first
    raise "No importer record found with system code HENNE." if @product_importer.nil?
    @product_importer
  end

  def importer system
    if system == :fenix
      @importer ||= Company.importers.where(fenix_customer_number: "887634400RM0001").first
      raise "No Fenix importer record found with Tax ID 887634400RM0001." if @importer.nil?
      @importer
    else
      product_importer
    end
  end

  def product_values system, part_number, country_origin_code, order_number
    value_multiplier = BigDecimal("1.3")

    invoice_line = find_invoice_line(order_number, country_origin_code, part_number)
    tariff = invoice_line.commercial_invoice_tariffs.first if invoice_line

    unique_identifier = "#{product_importer.system_code}-#{part_number}"

    # Product should NEVER be missing as all these products should come through on the I1 feed before making it 
    # through on an I2
    product = Product.where(importer_id: product_importer.id, unique_identifier: unique_identifier).first
    values = {part_number: part_number, unique_identifier: unique_identifier, order_number: order_number, country_origin: country_origin_code}
    if product
      values[:product] = product

      # Product value comes from the US invoice line first...then fall back to the product if we can't determine a value
      if tariff.try(:entered_value).try(:nonzero?) && invoice_line.try(:quantity).try(:nonzero?)
        values[:product_value] = (tariff.entered_value / invoice_line.quantity).round(2)
      else
        values[:product_value] = product.custom_value(cdefs[:prod_value])
      end
      values[:product_value] = (BigDecimal(values[:product_value].to_s) * value_multiplier) if values[:product_value]
      values[:mid] = invoice_line.try(:mid)

      classification = product.classifications.find {|c| c.country.try(:iso_code) == (system == :fenix ? "CA" : "US") }
      if classification
        # Tariff description is not sent to Kewill, so don't bother making the custom value lookup
        values[:description] = classification.custom_value(cdefs[:class_customs_description])
        values[:hts] = classification.tariff_records.first.try(:hts_1)
      end

      # Fall back to the commercial invoice line if the product doesn't have tariff description / hts filled in
      # Can't use HTS for fenix, since the invoice line is from the US tariff
      values[:description] = tariff.try(:tariff_description) if values[:description].blank?
      values[:hts] = tariff.try(:hts_code) if system == :kewill && values[:hts].blank?

      # What really matters here is that product_value is found and the tariff is present
      values[:missing_data] = values[:hts].blank? || values[:product_value].nil? || values[:description].blank?
    else
      values[:missing_data] = true
    end

    
    if system == :fenix 
      # Set the quantity to 999,999.99 if we're doing a Canadian file...quantity can't be missing from
      # the EDI 810 feed we use to feed the data to Fenix, so we're using an absurd value to indicate that it's missing,
      # and then sending an exception report to CA ops indicating missing data.
      if values[:product_value].nil?
        values[:product_value] = BigDecimal("999999.99")
      end
    elsif system == :kewill
      values[:missing_data] = values[:mid].blank?
    end

    values
  end

  def find_invoice_line order_number, country_origin, part_number
    base_query = CommercialInvoiceLine.joins(:entry, :commercial_invoice).
      where(entries: {importer_id: product_importer.id}).where("entries.release_date IS NOT NULL").
      where(commercial_invoices: {invoice_number: order_number}).
      where(country_origin_code: country_origin).
      order("entries.release_date DESC")
      
    matched_line = nil
    matched_line = base_query.where(part_number: part_number).first
    if matched_line.nil?
      partial_matches = base_query.all
      # Whoever is keying HM entries doesn't always key the part number, but the way H&M orders work is generally
      # to only have a single line on the order (which equates to our commercial invoice).  
      # These means that we can consider the invoice line a match if there's a only single line on the invoice.
      partial_matches.each do |pm|
        matched_line = pm if pm.commercial_invoice.commercial_invoice_lines.length == 1
        break unless matched_line.nil?
      end
    end

    matched_line
  end

  def generate_and_send_us_files invoice, rows, missing_product_data
    pdf_data = make_pdf_info(invoice, rows)
    spreadsheet = build_addendum_spreadsheet(invoice, rows)
    Tempfile.open(["HM-Invoice", ".pdf"]) do |file|
      file.binmode
      OpenChain::CustomHandler::CommercialInvoicePdfGenerator.render_content file, pdf_data

      Attachment.add_original_filename_method file, "Invoice #{Attachment.get_sanitized_filename(invoice.invoice_number)}.pdf"

      Tempfile.open(["HM-Addendum", ".xls"]) do |wb|
        wb.binmode
        spreadsheet.write wb
        Attachment.add_original_filename_method wb, "Invoice Addendum #{Attachment.get_sanitized_filename(invoice.invoice_number)}.xls"
        OpenMailer.send_simple_html(["Brampton-H&M.cl.us@geodis.com", "OnlineDCPlainfield@hm.com"], "[VFI Track] H&M Returns Shipment # #{invoice.invoice_number}", "The Commercial Invoice printout and addendum for invoice # #{invoice.invoice_number} is attached to this email.", [file, wb], reply_to: "nb@vandegriftinc.com", bcc: "nb@vandegriftinc.com").deliver!
      end
    end

    if missing_product_data.length > 0
      exception_spreadsheet = build_missing_product_spreadsheet(invoice.invoice_number, missing_product_data, :kewill) 
      Tempfile.open(["HM-Invoice-Exceptions", ".xls"]) do |wb|
        wb.binmode
        exception_spreadsheet.write wb
        Attachment.add_original_filename_method wb, "#{Attachment.get_sanitized_filename(invoice.invoice_number)} Exceptions.xls"
        OpenMailer.send_simple_html(["nb@vandegriftinc.com"], "[VFI Track] H&M Commercial Invoice #{invoice.invoice_number} Exceptions", "The Exception report for invoice # #{invoice.invoice_number} is attached to this email.", [wb]).deliver!
      end
    end
  end

  def generate_and_send_ca_files invoice, rows, missing_product_data
    spreadsheet = build_addendum_spreadsheet(invoice, rows)
    exception_spreadsheet = build_missing_product_spreadsheet(invoice.invoice_number, missing_product_data, :fenix) if missing_product_data.length > 0

    files = []
    begin
      files << create_tempfile_report(spreadsheet, "Invoice #{Attachment.get_sanitized_filename(invoice.invoice_number)}.xls")
      files << create_tempfile_report(exception_spreadsheet, "#{Attachment.get_sanitized_filename(invoice.invoice_number)} Exceptions.xls") if exception_spreadsheet

      OpenMailer.send_simple_html(["hm_ca@vandegriftinc.com"], "H&M Commercial Invoice #{invoice.invoice_number}", "The Commercial Invoice #{exception_spreadsheet ? " and the Exception report " : ""}for invoice # #{invoice.invoice_number} is attached to this email.", files).deliver!
    ensure
      files.each do |f|
        f.close! unless f.closed?
      end
    end
  end

  def create_tempfile_report workbook, filename
    tf = nil
    written = false
    begin
      tf = Tempfile.open([File.basename(filename, ".*"), File.extname(filename)])
      tf.binmode
      Attachment.add_original_filename_method tf, filename
      workbook.write tf
      tf.flush
      written = true
    ensure
      tf.close! unless written || tf.closed?
    end

    tf
  end

  def make_pdf_info invoice, rows
    i = OpenChain::CustomHandler::CommercialInvoicePdfGenerator::INVOICE.new
    i.control_number = invoice.invoice_number
    i.exporter_reference = invoice.invoice_number
    i.export_date = invoice.invoice_date
    i.exporter_address = OpenChain::CustomHandler::CommercialInvoicePdfGenerator::ADDRESS.new
    i.exporter_address.name = "OHL"
    i.exporter_address.line_1 = "300 Kennedy Rd S Unit B"
    i.exporter_address.line_2 = "Brampton, ON, L6W 4V2"
    i.exporter_address.line_3 = "Canada"

    i.consignee_address = OpenChain::CustomHandler::CommercialInvoicePdfGenerator::ADDRESS.new
    i.consignee_address.name = "H&M Hennes & Mauritz"
    i.consignee_address.line_1 = "1600 River Road, Building 1"
    i.consignee_address.line_2 = "Burlington Township, NJ 08016"
    i.consignee_address.line_3 = "(609) 239-8703"

    i.terms = "FOB Windsor Ontario"
    i.origin = "Ontario"
    i.destination = "Indiana"
    i.local_carrier = text_value(rows.first[14])
    i.export_carrier = i.local_carrier
    i.port_of_entry = "Detroit, MI"
    i.lading_location = "Ontario"
    i.related = false
    i.duty_for = "Consignee"
    i.date_of_sale = i.export_date
    packages = invoice.commercial_invoice_lines.map(&:quantity).compact
    packages = packages.length > 0 ? packages.sum : 0

    i.total_packages = "#{sprintf("%d", packages)} #{"Package".pluralize(packages)}"
    # We should use the gross weight from the rows here rather than the invoice since the invoice's gross weight field is an integer
    weight = BigDecimal("0")
    rows.each do |row|
      weight += (decimal_value(row[16]).presence || BigDecimal("0"))
    end

    i.total_gross_weight = "#{number_with_precision((weight / BigDecimal("1000")), precision: 2, strip_insignificant_zeros: true)} KG"
    i.description_of_goods = "For Customs Clearance by: Vandegrift\nFor the account of: H & M HENNES & MAURITZ L.P.\nMail order goods being returned by the Canadian\nConsumer for credit or exchange."
    i.export_reason = "Not Sold"
    i.mode_of_transport = "Road"
    i.containerized = false
    i.owner_agent = "Agent"
    total = invoice.commercial_invoice_lines.inject(BigDecimal("0")) {|sum, line| sum + line.value }
    i.invoice_total = number_to_currency(total)

    i.employee = "Shahzad Dad"
  
    i.firm_address = OpenChain::CustomHandler::CommercialInvoicePdfGenerator::ADDRESS.new
    i.firm_address.name = "OHL"
    i.firm_address.line_1 = "281 AirTech Pkwy. Suite 191"
    i.firm_address.line_2 = "Plainfield, IN 46168"
    i.firm_address.line_3 = "USA"

    i
  end

  def build_addendum_spreadsheet invoice, rows
    wb, sheet = XlsMaker.create_workbook_and_sheet invoice.invoice_number, ["Shipment ID", "Part Number", "Description", "MID", "Country of Origin", "HTS", "Net Weight", "Net Weight UOM", "Unit Price", "Quantity", "Total Value"]

    totals = {quantity: BigDecimal("0"), weight: BigDecimal("0"), value: BigDecimal("0")}
    counter = 0
    widths = []
    if invoice.commercial_invoice_lines.length == 0
      XlsMaker.add_body_row sheet, (counter += 1), [invoice.invoice_number]  
    else
      invoice.commercial_invoice_lines.each do |l|
        source_row = rows[counter]
        weight = (decimal_value(source_row[16]).presence || BigDecimal("0"))

        t = l.commercial_invoice_tariffs.first

        row = [invoice.invoice_number, l.part_number, t.try(:tariff_description), l.mid, l.country_origin_code, t.try(:hts_code).try(:hts_format), weight, "G", l.unit_price, l.quantity, l.value]
        totals[:quantity] += (l.quantity.presence || 0)
        totals[:weight] += weight
        totals[:value] += (l.value.presence || 0)

        XlsMaker.add_body_row sheet, (counter += 1), row, widths
      end

    end

    XlsMaker.add_body_row sheet, (counter += 1), ["", "", "", "", "", "", totals[:weight], "", "", totals[:quantity], totals[:value]], widths

    wb
  end

  def build_missing_product_spreadsheet invoice_number, missing_products, destination_system
    wb, sheet = XlsMaker.create_workbook_and_sheet "#{invoice_number} Exceptions", ["Part Number", "H&M Order #", "H&M Country Origin", "H&M Description", "PO Numbers", "US HS Code", "CA HS Code", "Product Value", "MID", "Product Link", "US Entry Links", "Resolution"]
    counter = 0
    widths = [50, 50, 50, 50, 50, 50, 50, 50, 50, 50]
    missing_products.each do |prod|
      part_number = prod[:part_number]

      if prod[:product]
        product = prod[:product]
        
        ca_classification = product.classifications.find {|c| c.country.try(:iso_code) == "CA"}
        ca_tariff = ca_classification.try(:tariff_records).try(:first).try(:hts_1)
        us_tariff = product.classifications.find {|c| c.country.try(:iso_code) == "US" }.try(:tariff_records).try(:first).try(:hts_1)
        po_numbers = product.custom_value(cdefs[:prod_po_numbers]).to_s.split("\n").map(&:strip)

        resolution = nil
        if destination_system == :fenix
          if us_tariff.blank?
            resolution = "Use Part Number and H&M Order # (Invoice Number in US Entry) to lookup the missing information in the linked US Entry then add the Canadian classification in linked Product record."
          elsif ca_tariff.blank?
            resolution = "Use linked Product and add Canadian classifiction in VFI Track."
          elsif prod[:product_value].nil? || prod[:product_value].zero? || prod[:product_value] >= BigDecimal("999999.99")
            # If value is missing, we put an absurdly high value in, otherwise the EDI fails.  Fenix will flag this value too, or so we're told.
            resolution = "The Product Value field must be filled in on the linked Product using information from any US Entries the product appears on."
          end
        elsif destination_system == :kewill
          resolution = "Use Part Number and the H&M Order # (Invoice Number in US Entry) to lookup the missing information from the source US Entry."
        end

        entry = nil
        if po_numbers.length > 0
          entry = Entry.joins(commercial_invoices: [:commercial_invoice_lines]).where(source_system: "Alliance", customer_number: "HENNE").where(commercial_invoices: {invoice_number: po_numbers}).order("file_logged_date DESC").first
        end

        XlsMaker.add_body_row sheet, (counter +=1), [part_number, prod[:order_number], prod[:country_origin], product.name, po_numbers.join(", "), us_tariff.try(:hts_format), ca_tariff.try(:hts_format), prod[:product_value], prod[:mid], XlsMaker.create_link_cell(product.excel_url, part_number), (entry ? XlsMaker.create_link_cell(entry.excel_url, entry.broker_reference) : ""), resolution], widths
      else
        XlsMaker.add_body_row sheet, (counter +=1), [part_number, prod[:order_number], prod[:country_origin], "", "", "", "", prod[:product_value], prod[:mid], "", "", "No Product record exists in VFI Track.  H&M did not send an I1 file for this product."], widths
      end
    end

    wb
  end

  def generate_and_send_pars_pdf file_data
    Tempfile.open(["ParsCoversheet", ".pdf"]) do |tempfile|
      tempfile.binmode
      OpenChain::CustomHandler::Hm::HmParsPdfGenerator.generate_pars_pdf(file_data, tempfile)
      # Use the first invoice date from the data 
      data = file_data.find {|d| !d.invoice_date.nil? }
      date = (data.nil? ? Time.zone.now.to_date : data.invoice_date).strftime("%Y-%m-%d")
      filename = "PARS Coversheet - #{date}.pdf"
      Attachment.add_original_filename_method(tempfile, filename)
      OpenMailer.send_simple_html(["H&M_supervisors@ohl.com", "Ronald.Colbert@purolator.com", "Terri.Bandy@purolator.com", "Mike.Devitt@purolator.com"], filename, "See attached PDF file for the list of PARS numbers to utilize.", [tempfile], cc: ["hm_ca@vandegriftinc.com"], reply_to: "hm_ca@vandegriftinc.com").deliver!
    end
  end



end; end; end; end;