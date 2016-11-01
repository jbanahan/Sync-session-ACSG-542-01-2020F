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
    new.parse(file)
  end

  def parse file_contents, forward_to_entry_system: true
    rows = foreach(file_contents, skip_blank_lines: true)
    system = determine_system(rows.first)

    # Canadian customs requires that electronically filed PARS entries must be under 999 lines (WTF, eh?).
    # So, we need to chunk the file into groups of 999 lines for CA and then process each chunk of lines like
    # a completely separate file.
    files = split_file(system, rows)
    files.each_with_index do |file, x|
      process_file(system, file, x + 1, forward_to_entry_system)
    end

    nil
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

    # The file comes in with shipment numbers interlaced together (WTF)...so lets sort them based
    # on the shipment number and then line number
    rows = rows.sort {|row1, row2|
      val = row1[0].to_s.strip <=> row2[0].to_s.strip
      if val == 0
        val = row1[1].to_i <=> row2[1].to_i
      end
      val
    }

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
        generate_and_send_us_files invoice, rows
      end
    end
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

    values = product_values(system, i.part_number)

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

  def product_values system, part_number
    value_multiplier = BigDecimal("1.3")

    importer = product_importer
    unique_identifier = "#{importer.system_code}-#{part_number}"
    product = Product.where(importer_id: importer.id, unique_identifier: unique_identifier).first
    values = {part_number: part_number, unique_identifier: unique_identifier}
    if product
      values[:product] = product
      values[:product_value] = product.custom_value(cdefs[:prod_value])
      values[:product_value] = (BigDecimal(values[:product_value].to_s) * value_multiplier) if values[:product_value]
      values[:order_number] = product.custom_value(cdefs[:prod_value_order_number])

      classification = product.classifications.find {|c| c.country.try(:iso_code) == (system == :fenix ? "CA" : "US") }
      if classification
        # Tariff description is not sent to Kewill, so don't bother making the custom value lookup
        values[:description] = classification.custom_value(cdefs[:class_customs_description]) if system == :fenix
        values[:hts] = classification.tariff_records.first.try(:hts_1)
      end

      if system == :kewill
        # Canada's customs description is "better" than the US one we use (which is just the tariff chapter notes)
        # We'll use the better description on the invoice addendum excel file
        classification = product.classifications.find {|c| c.country.try(:iso_code) == "CA" }
        if classification
          values[:description] = classification.custom_value(cdefs[:class_customs_description])
        end
      end
    else
      values[:missing_data] = true
    end

    if system == :kewill && values[:order_number]
      # Need to pull the MID from the Entry
      invoice_line = CommercialInvoiceLine.joins(:entry).where(part_number: part_number).where(commercial_invoices: {invoice_number: values[:order_number]}, entries: {importer_id: product_importer.id}).order("entries.release_date desc").first
      if invoice_line
        values[:mid] = invoice_line.mid
      end
    end

    
    if system == :fenix 
      # What really matters here is that product_value is found and the canadian tariff is presen
      values[:missing_data] = values[:hts].blank? || values[:product_value].nil?

      # Set the quantity to 999,999.99 if we're doing a Canadian file...quantity can't be missing from
      # the EDI 810 feed we use to feed the data to Fenix, so we're using an absurd value to indicate that it's missing,
      # and then sending an exception report to CA ops indicating missing data.
      if values[:product_value].nil?
        values[:product_value] = BigDecimal("999999.99")
      end
    end

    values
  end

  def generate_and_send_us_files invoice, rows
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
        OpenMailer.send_simple_html(["Brampton-H&M@ohl.com", "OnlineDCPlainfield@hm.com"], "[VFI Track] H&M Returns Shipment # #{invoice.invoice_number}", "The Commercial Invoice printout and addendum for invoice # #{invoice.invoice_number} is attached to this email.", [file, wb], reply_to: "nb@vandegriftinc.com", bcc: "nb@vandegriftinc.com").deliver!
      end
    end
  end

  def generate_and_send_ca_files invoice, rows, missing_product_data
    spreadsheet = build_addendum_spreadsheet(invoice, rows)
    exception_spreadsheet = build_missing_product_spreadsheet(invoice.invoice_number, missing_product_data) if missing_product_data.length > 0

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

  def build_missing_product_spreadsheet invoice_number, missing_products
    wb, sheet = XlsMaker.create_workbook_and_sheet "#{invoice_number} Exceptions", ["Part Number", "H&M Description", "PO Numbers", "US HS Code", "CA HS Code", "Product Link", "US Entry Links", "Resolution"]
    counter = 0
    widths = [50, 50, 50, 50, 50, 50, 50, 50]
    missing_products.each do |prod|
      part_number = prod[:part_number]

      if prod[:product]
        product = prod[:product]
        
        ca_classification = product.classifications.find {|c| c.country.try(:iso_code) == "CA"}
        ca_tariff = ca_classification.try(:tariff_records).try(:first).try(:hts_1)
        us_tariff = product.classifications.find {|c| c.country.try(:iso_code) == "US" }.try(:tariff_records).try(:first).try(:hts_1)
        po_numbers = product.custom_value(cdefs[:prod_po_numbers]).to_s.split("\n").map(&:strip)

        resolution = nil
        if us_tariff.blank?
          resolution = "Use Part Number and PO Number(s) (Invoice Number in US Entry) to lookup the missing information in the linked US Entry then add the Canadian classification in linked Product record."
        elsif ca_tariff.blank?
          resolution = "Use linked Product and add Canadian classifiction in VFI Track."
        end

        entry = nil
        if po_numbers.length > 0
          entry = Entry.joins(commercial_invoices: [:commercial_invoice_lines]).where(source_system: "Alliance", customer_number: "HENNE").where(commercial_invoices: {invoice_number: po_numbers}).order("file_logged_date DESC").first
        end

        XlsMaker.add_body_row sheet, (counter +=1), [part_number, product.name, po_numbers.join(", "), us_tariff.try(:hts_format), ca_tariff.try(:hts_format), XlsMaker.create_link_cell(product.excel_url, part_number), (entry ? XlsMaker.create_link_cell(entry.excel_url, entry.broker_reference) : ""), resolution], widths
      else
        XlsMaker.add_body_row sheet, (counter +=1), [part_number, "", "", "", "", "", "", "No Product record exists in VFI Track.  H&M did not send an I1 file for this product."], widths
      end
    end

    wb
  end

end; end; end; end;