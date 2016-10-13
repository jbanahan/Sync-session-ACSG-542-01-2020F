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

  def initialize 
    @cdefs = self.class.prep_custom_definitions [:prod_value_order_number, :prod_value, :class_customs_description]
  end

  def parse file_contents, forward_to_entry_system: true
    rows = foreach(file_contents, skip_blank_lines: true)
    system = determine_system(rows.first)
    # NOTE: the invoices we're creating here are NOT saved...we're just using the datastructure as a passthrough
    # for the Fenix / Kewill file transfers
    invoice = make_invoice(system, rows.first)

    # The index position of the invoice line must correlate with the index of the row from the file do to how we're pulling
    # some data from the rows for the pdf and excel sheets.
    #
    # In other words, don't process the rows in any other order than what they came in from the file.
    rows.each do |row|
      set_invoice_line_info(system, invoice.commercial_invoice_lines.build, row)
    end

    set_totals(invoice)

    if forward_to_entry_system
      if system == :fenix
        OpenChain::CustomHandler::FenixNdInvoiceGenerator.generate invoice
        # Generate the files for the carrier and send them
        generate_and_send_ca_files invoice, rows
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

  def make_invoice system, line
    invoice = CommercialInvoice.new
    invoice.importer = importer(system)
    invoice.invoice_number = text_value(line[0])
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
    nil
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
    product = Product.where(importer_id: importer.id, unique_identifier: "#{importer.system_code}-#{part_number}").first
    values = {}
    if product
      values[:product_value] = product.custom_value(@cdefs[:prod_value])
      values[:product_value] = (BigDecimal(values[:product_value].to_s) * value_multiplier) if values[:product_value]
      values[:order_number] = product.custom_value(@cdefs[:prod_value_order_number])

      classification = product.classifications.find {|c| c.country.try(:iso_code) == (system == :fenix ? "CA" : "US") }
      if classification
        # Tariff description is not sent to Kewill, so don't bother making the custom value lookup
        values[:description] = classification.custom_value(@cdefs[:class_customs_description]) if system == :fenix
        values[:hts] = classification.tariff_records.first.try(:hts_1)
      end

      if system == :kewill
        # Canada's customs description is "better" than the US one we use (which is just the tariff chapter notes)
        # We'll use the better description on the invoice addendum excel file
        classification = product.classifications.find {|c| c.country.try(:iso_code) == "CA" }
        if classification
          values[:description] = classification.custom_value(@cdefs[:class_customs_description])
        end
      end
    end

    if system == :kewill && values[:order_number]
      # Need to pull the MID from the Entry
      invoice_line = CommercialInvoiceLine.joins(:entry).where(part_number: part_number).where(commercial_invoices: {invoice_number: values[:order_number]}, entries: {importer_id: product_importer.id}).order("entries.release_date desc").first
      if invoice_line
        values[:mid] = invoice_line.mid
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

  def generate_and_send_ca_files invoice, rows
    spreadsheet = build_addendum_spreadsheet(invoice, rows)
    Tempfile.open(["HM-Invoice", ".xls"]) do |wb|
      wb.binmode
      spreadsheet.write wb
      Attachment.add_original_filename_method wb, "Invoice #{Attachment.get_sanitized_filename(invoice.invoice_number)}.xls"
      OpenMailer.send_simple_html(["hm_ca@vandegriftinc.com"], "H&M Commercial Invoice #{invoice.invoice_number}", "The Commercial Invoice for invoice # #{invoice.invoice_number} is attached to this email.", wb).deliver!
    end
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

end; end; end; end;