require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/vandegrift/fenix_nd_invoice_810_generator'

# HM (for some reason) names all their feeds with random numeric values.
# This is for processing an XML file containing truck crossing data 
# for trucks into and out of Canada.
#
# Trucks into Canada are delivering online purchases and the data will
# get handled and fed to Fenix.
#
# Trucks out of Canada are delivering online returns and the data will
# get handled by our US Kewill system.
module OpenChain; module CustomHandler; module Hm; class HmI978Parser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::IntegrationClientParser
  include ActionView::Helpers::NumberHelper

  def self.parse_file file_content, log, opts = {}
    # Each file is supposed to represent a single truck shipment's data, so we should be ok just parsing them all 
    # in a single parse attempt and not breaking them up into smaller distinct delayed job units (like we might do 
    # with an EDI file)
    user = User.integration
    parser = self.new
    REXML::XPath.each(REXML::Document.new(file_content), "/ns0:CustomsTransactionalDataTransaction/Payload/CustomsTransactionalData/BILLING_SHIPMENT") do |xml|
      parser.process_shipment_xml(xml, user, opts[:bucket], opts[:key])
    end
  end

  def process_shipment_xml(xml, user, bucket, filename)
    shipment_data = extract_shipment_data(xml)
    if fenix?(shipment_data)
      shipments = split_shipment(shipment_data, max_fenix_invoice_length)
    else
      shipments = [shipment_data]
    end

    if !primary_ca_import_parser? && !primary_us_import_parser?
      inbound_file.add_info_message("i978 process is not fully enabled.  No files will be emitted from this parser.")
    end

    invoices = []
    shipments.each do |shipment|
      i = process_shipment_data(shipment, user, bucket, filename)
      invoices << i unless i.nil?
    end

    if invoices.length > 0 && fenix?(invoices.first) && primary_ca_import_parser?
      generate_and_send_pars_pdf(invoices)
      check_unused_pars_count()
    end

    invoices
  end

  def process_shipment_data shipment, user, bucket, filename
    inv = find_or_create_invoice(shipment) do |invoice|
      invoice.last_file_bucket = bucket
      invoice.last_file_path = filename
      
      set_invoice_header(shipment, invoice)

      shipment["DELIVERY_ITEMS"].each do |item|
        line = invoice.invoice_lines.build
        set_invoice_line(shipment, item, line)
      end

      set_invoice_totals(invoice)

      invoice.save!
      invoice.create_snapshot user, nil, filename
    end

    return nil unless inv

    if fenix?(inv) && primary_ca_import_parser?
      generate_and_send_ca_files(inv)
    elsif kewill?(inv) && primary_us_import_parser?
      generate_and_send_us_files(inv)
    end

    inv
  end

  def generate_missing_parts_spreadsheet invoice
    # The only thing we need to worry about being missing from an invoice now is the hts number and MID (Kewill only)
    builder = XlsxBuilder.new
    sheet = builder.create_sheet "#{invoice.invoice_number} Exceptions", headers: ["Part Number", "H&M Order #", "H&M Country Origin", "H&M Description", "US HS Code", "CA HS Code", "Product Value", "MID", "Product Link", "US Entry Links", "Resolution"]
    system = customs_system(invoice)

    lines = 0
    invoice.invoice_lines.each do |line|
      if line.product_id.nil?
        resolution = "No Product record exists in VFI Track.  H&M did not send an I1 file for this product."
      else
        if fenix?(invoice)
          if line.hts_number.blank?
            resolution = "Use linked Product and add Canadian classification in VFI Track."
          end
        else
          if line.hts_number.blank? || line.mid.blank?
            resolution = "Use Part Number and the H&M Order # (Invoice Number in US Entry) to lookup the missing information from the source US Entry."
          end
        end
      end

      next if resolution.blank?

      entry = nil
      if line.customer_reference_number.present?
        entry = Entry.joins(:commercial_invoices).
                    where(source_system: "Alliance", importer_id: product_importer.id).
                    where("release_date IS NOT NULL").
                    where(commercial_invoices: {invoice_number: line.customer_reference_number}).
                    where("export_country_codes <> ?", "CA").
                    order("release_date DESC").first
      end

      builder.add_body_row sheet, build_missing_parts_row(builder, line, entry, resolution)
      lines += 1
    end
    builder.freeze_horizontal_rows sheet, 1

    lines > 0 ? builder : nil
  end

  def generate_invoice_addendum invoice
    builder = XlsxBuilder.new
    sheet = builder.create_sheet "#{invoice.invoice_number}", headers: ["Shipment ID", "Part Number", "Description", "MID", "Country of Origin", "HTS", "Net Weight", "Net Weight UOM", "Unit Price", "Quantity", "Total Value"]
    total_quantity = BigDecimal("0")
    invoice.invoice_lines.each do |l|
      total_quantity += l.quantity if l.quantity
      builder.add_body_row sheet, [invoice.invoice_number, l.part_number, l.part_description, l.mid, l.country_origin&.iso_code, l.hts_number&.hts_format, l.net_weight, l.net_weight_uom, l.unit_price, l.quantity&.to_i, l.value_foreign]
    end

    builder.add_body_row sheet, [nil, nil, nil, nil, nil, nil, invoice.net_weight, nil, nil, total_quantity.to_i, invoice.invoice_total_foreign]
    builder.freeze_horizontal_rows sheet, 1

    builder
  end

  def make_pdf_info invoice
    i = OpenChain::CustomHandler::CommercialInvoicePdfGenerator::INVOICE.new
    i.control_number = invoice.invoice_number
    i.exporter_reference = invoice.invoice_number
    i.export_date = invoice.invoice_date
    i.exporter_address = OpenChain::CustomHandler::CommercialInvoicePdfGenerator::ADDRESS.new
    i.exporter_address.name = "Geodis"
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
    i.local_carrier = invoice.invoice_lines.first.carrier_name
    i.export_carrier = i.local_carrier
    i.port_of_entry = "Detroit, MI"
    i.lading_location = "Ontario"
    i.related = false
    i.duty_for = "Consignee"
    i.date_of_sale = i.export_date
    packages = invoice.invoice_lines.map(&:quantity).compact
    packages = packages.length > 0 ? packages.sum : 0

    i.total_packages = "#{sprintf("%d", packages)} #{"Package".pluralize(packages)}"

    i.total_gross_weight = "#{number_with_precision(invoice.gross_weight, precision: 2, strip_insignificant_zeros: true)} KG"
    i.description_of_goods = "For Customs Clearance by: Vandegrift\nFor the account of: H & M HENNES & MAURITZ L.P.\nMail order goods being returned by the Canadian\nConsumer for credit or exchange."
    i.export_reason = "Not Sold"
    i.mode_of_transport = "Road"
    i.containerized = false
    i.owner_agent = "Agent"
    i.invoice_total = number_to_currency(invoice.invoice_total_foreign)

    i.employee = "Shahzad Dad"
    
    i.firm_address = OpenChain::CustomHandler::CommercialInvoicePdfGenerator::ADDRESS.new
    i.firm_address.name = "Geodis"
    i.firm_address.line_1 = "281 AirTech Pkwy. Suite 191"
    i.firm_address.line_2 = "Plainfield, IN 46168"
    i.firm_address.line_3 = "USA"

    i
  end

  class HmShipmentData
    attr_accessor :invoice_number, :pars_number, :cartons, :weight, :invoice_date
  end

  def generate_and_send_pars_pdf invoices
    file_data = invoices.map { |i| generate_file_totals(i) }

    Tempfile.open(["ParsCoversheet", ".pdf"]) do |tempfile|
      tempfile.binmode
      OpenChain::CustomHandler::Hm::HmParsPdfGenerator.generate_pars_pdf(file_data, tempfile)
      # Use the first invoice date from the data 
      data = file_data.find {|d| !d.invoice_date.nil? }
      date = (data.nil? ? Time.zone.now.to_date : data.invoice_date).strftime("%Y-%m-%d")
      filename = "PARS Coversheet - #{date}.pdf"
      Attachment.add_original_filename_method(tempfile, filename)
      OpenMailer.send_simple_html(email_pars_coversheet_to, filename, "See attached PDF file for the list of PARS numbers to utilize.", [tempfile], cc: ["hm_ca@vandegriftinc.com", "afterhours@vandegriftinc.com"], reply_to: "hm_ca@vandegriftinc.com").deliver!
    end
  end

  def check_unused_pars_count
    pars_count = DataCrossReference.unused_pars_count
    if pars_count < pars_threshold
      OpenMailer.send_simple_html(email_unused_pars_to, "More PARS Numbers Required", "#{pars_count} PARS numbers are remaining to be used for H&M border crossings.  Please supply more to Vandegrift to ensure future crossings are not delayed.", [], reply_to: "hm_support@vandegriftinc.com").deliver!
    end
  end

  private 

    def generate_and_send_ca_files invoice
      # If this file invoice has already been synced...then don't send anything
      sr = invoice.sync_records.find { |sr| sr.trading_partner == "CA i978" }
      return if sr&.sent_at

      if sr.nil?
        sr = invoice.sync_records.build trading_partner: "CA i978"
      end

      OpenChain::CustomHandler::Vandegrift::FenixNdInvoice810Generator.new.generate_and_send_810 invoice, sr
      addendum_builder = generate_invoice_addendum(invoice)
      exception_builder = generate_missing_parts_spreadsheet(invoice)

      files = []
      begin
        files << create_tempfile_report(addendum_builder, "Invoice #{Attachment.get_sanitized_filename(invoice.invoice_number)}.xlsx")
        files << create_tempfile_report(exception_builder, "#{Attachment.get_sanitized_filename(invoice.invoice_number)} Exceptions.xlsx") if exception_builder

        OpenMailer.send_simple_html(email_canadian_files_to, "H&M Commercial Invoice #{invoice.invoice_number}", "The Commercial Invoice #{exception_builder ? " and the Exception report " : ""}for invoice # #{invoice.invoice_number} is attached to this email.", files).deliver!
      ensure
        files.each do |f|
          f.close! unless f.closed?
        end
      end
      sr.sent_at = Time.zone.now
      sr.confirmed_at = (Time.zone.now + 1.minute)
      sr.save!
      nil
    end

    def generate_and_send_us_files invoice
      # If this file invoice has already been synced...then don't send anything
      sr = invoice.sync_records.find { |sr| sr.trading_partner == "US i978" }
      return if sr&.sent_at

      if sr.nil?
        sr = invoice.sync_records.build trading_partner: "US i978"
      end

      OpenChain::CustomHandler::Vandegrift::KewillInvoiceGenerator.new.generate_and_send_invoice invoice, sr
      addendum_builder = generate_invoice_addendum(invoice)
      exception_builder = generate_missing_parts_spreadsheet(invoice)
      pdf_data = make_pdf_info(invoice)

      files = []
      begin
        files << create_tempfile_report(addendum_builder, "Invoice Addendum #{Attachment.get_sanitized_filename(invoice.invoice_number)}.xlsx")
        files << create_tempfile_report(nil, "Invoice #{Attachment.get_sanitized_filename(invoice.invoice_number)}.pdf", write_lambda: lambda {|file| OpenChain::CustomHandler::CommercialInvoicePdfGenerator.render_content file, pdf_data}) 

        OpenMailer.send_simple_html(email_us_files_to, "[VFI Track] H&M Returns Shipment # #{invoice.invoice_number}", "The Commercial Invoice printout and addendum for invoice # #{invoice.invoice_number} is attached to this email.", files, reply_to: "nb@vandegriftinc.com", bcc: "nb@vandegriftinc.com").deliver!
      ensure
        files.each do |f|
          f.close! unless f.closed?
        end
      end

      if exception_builder
        file = nil
        begin
          file = create_tempfile_report(exception_builder, "#{Attachment.get_sanitized_filename(invoice.invoice_number)} Exceptions.xlsx")
          OpenMailer.send_simple_html(email_us_exception_files_to, "[VFI Track] H&M Commercial Invoice #{invoice.invoice_number} Exceptions", "The Exception report for invoice # #{invoice.invoice_number} is attached to this email.", [file]).deliver!
        ensure
          file.close unless file.closed?
        end
      end

      sr.sent_at = Time.zone.now
      sr.confirmed_at = (Time.zone.now + 1.minute)
      sr.save!
      nil
    end

    def create_tempfile_report builder, filename, write_lambda: nil
      tf = nil
      written = false
      begin
        tf = Tempfile.open([File.basename(filename, ".*"), File.extname(filename)])
        tf.binmode
        Attachment.add_original_filename_method tf, filename
        if write_lambda
          write_lambda.call tf
        else
          builder.write tf
        end
        tf.flush
        written = true
      ensure
        tf.close! unless written || tf.closed?
      end

      tf
    end

    def build_missing_parts_row builder, line, entry, resolution
      row = []
      row << line.part_number
      row << line.customer_reference_number
      row << line.country_origin&.iso_code
      row << line.part_description
      row << line.product&.hts_for_country(us)&.first&.hts_format
      row << line.product&.hts_for_country(ca)&.first&.hts_format
      row << line.value_foreign
      row << line.mid
      row << (line.product.nil? ? nil : builder.create_link_cell(line.product.excel_url, link_text: line.part_number))
      row << (entry.nil? ? nil : builder.create_link_cell(entry.excel_url, link_text: entry.broker_reference))
      row << resolution

      row
    end

    def set_invoice_header full_shipment, invoice
      shipment = full_shipment["SHIPMENT"]
      
      invoice.invoice_date = invoice_date(shipment)
      invoice.terms_of_sale = shipment["DeliveryTerms"]
      invoice.customer_reference_number = shipment["BillingDocumentNumber"]
      invoice.country_import = (kewill?(shipment)) ? us : ca

      # Pull the currency from the first line, the invoice is supposed to share the same currency over every line.
      lines = full_shipment["DELIVERY_ITEMS"]
      lines.each do |line|
        currency = line["Currency"]
        next if currency.blank?
        invoice.currency = currency
        break
      end
      nil
    end

    def set_invoice_totals invoice
      invoice.gross_weight = BigDecimal("0")
      invoice.net_weight = BigDecimal("0")
      invoice.invoice_total_foreign = BigDecimal("0")

      invoice.invoice_lines.each do |line|
        invoice.gross_weight_uom = line.gross_weight_uom if invoice.gross_weight_uom.blank?
        invoice.net_weight_uom = line.net_weight_uom if invoice.net_weight_uom.blank?
        invoice.gross_weight += line.gross_weight if line.gross_weight
        invoice.net_weight += line.net_weight if line.net_weight

        invoice.invoice_total_foreign += line.value_foreign if line.value_foreign
      end
      nil
    end

    def set_invoice_line shipment, item, line
      # This is actually the order number to the customer (.ie what you'd see on your 
      # order if you purchased something online.)
      line.po_number = item["SalesOrderNumber"]
      line.po_line_number = item["SalesOrderItemNumber"]
      line.part_number = item["ArticleNumber"].to_s[0..6]
      line.sku = item["ArticleNumber"]
      description = item["ArticleDescription"]
      composition = item["ArticleComposition"]
      if description.blank?
        part_description = composition
      elsif !composition.blank?
        part_description = "#{description} - #{composition}"
      else
        part_description = description
      end

      line.part_description = part_description
      line.quantity = parse_decimal(item["Quantity"])
      line.quantity_uom = item["UOM"]
      line.unit_price = parse_decimal(item["ItemPrice"])
      line.country_origin = country_origin(item["COO"], kewill?(shipment))
      line.net_weight = parse_decimal(item["ItemNetWeight"])
      line.gross_weight = parse_decimal(item["ItemGrossWeight"])
      line.net_weight_uom = line.gross_weight_uom = item["UOMWeight"]
      line.master_bill_of_lading = item["CarrierTrackingNumber"]
      # This is the actual order number of the item on the US entry (which is the Invoice Number for us)
      line.customer_reference_number = item["HMOrderNumber"]
      line.carrier_name = shipment["SHIPMENT"]["CarrierName"]
      line.value_foreign = line.quantity * line.unit_price if line.quantity && line.unit_price
      line.customer_reference_number_2 = item["SSCCNumber"]
      line.secondary_po_number = item["HybrisOrderNumber"]
      line.secondary_po_line_number = item["HybrisOrderItemNumber"]

      # We don't need MID's for Canada imports only US Returns - Canada doesn't do MIDs
      if kewill?(shipment)
        invoice_line = find_commercial_invoice_line(line.customer_reference_number, line.country_origin&.iso_code, line.part_number)
        if invoice_line
          line.mid = invoice_line.mid
        end
      end

      # We need to now pull the hts number from the parts lib.  For the US hts numbers (.ie returns from Canada),
      # it should always be there.  We're populating the H&M parts lib directly from Entries, thus
      # the tariff number is populated there.
      product = find_product(line.part_number)
      if product
        line.product = product
        line.hts_number = product.hts_for_country(kewill?(shipment) ? us : ca).first
      end

      nil
    end

    def find_commercial_invoice_line order_number, country_origin, part_number
      return nil if [order_number, country_origin, part_number].any?(&:blank?)

      @commercial_invoice_lines ||= Hash.new do |h, k|
        h[k] = CommercialInvoiceLine.joins(commercial_invoice: [:entry]).
                where(entries: {importer_id: product_importer.id, source_system: "Alliance"}).where("entries.release_date IS NOT NULL").
                where(commercial_invoices: {invoice_number: k[0]}).
                where(country_origin_code: k[1], part_number: k[2]).
                where("export_country_codes <> ?", "CA").
                order("entries.release_date DESC").first
      end

      @commercial_invoice_lines[[order_number, country_origin, part_number]]
    end

    def find_product part_number
      @products ||= Hash.new do |h, k|
        h[k] = Product.where(importer_id: product_importer.id, unique_identifier: k).first
      end

      @products["#{product_importer.system_code}-#{part_number}"]
    end

    def find_or_create_invoice shipment_data
      shipment = shipment_data["SHIPMENT"]
      invoice_number = shipment.try(:[], "ExternalID")
      inbound_file.reject_and_raise("Expected to find Invoice Number in the BILLING_SHIPMENT/ExternalID element, but it was blank or missing.") if invoice_number.blank?

      invoice = nil
      Lock.acquire("Invoice-#{invoice_number}") do 

        i = Invoice.where(importer_id: importer(shipment_data).id, invoice_number: invoice_number).first_or_create!
        inbound_file.add_identifier :invoice_number, i.invoice_number, object: i

        if process_file? i, shipment
          invoice = i
        end
      end

      # This is here because I need to run the pars lookup outside a transaction, this is because we need to immediately mark the 
      # pars number as utilized.  If we didn't do this, and instead ran this inside the lock transacion used below it's possible
      # to have 2 simultaneous transactions open at the same time where the pars number is not used, both would select the same one
      # and then both use it.  The ideal solution here is probably to write a stored proc that doles out the next number which 
      # would mean we could then reference it from anywhere, but that's rather involved for this single case.

      # If this isn't the primary parser for CA, we can't use Pars Numbers.
      if invoice.customer_reference_number_2.blank? && fenix?(shipment_data) && primary_ca_import_parser?
        invoice.customer_reference_number_2 = DataCrossReference.find_and_mark_next_unused_hm_pars_number
        inbound_file.add_identifier :pars_number, invoice.customer_reference_number_2
        # save the invoice immediately, so that we ensure even if this invoice number errors for some reason that when it's reloaded
        # the same pars number will be used
        invoice.save!
      end

      Lock.db_lock(invoice) do
        if process_file?(invoice, shipment)
          invoice.last_exported_from_source = invoice_date(shipment)
          invoice.invoice_lines.destroy_all

          yield invoice
        else
          invoice = nil
        end
      end

      invoice
    end

    def fenix? shipment_data
      customs_system(shipment_data) == :fenix
    end

    def kewill? shipment_data
      customs_system(shipment_data) == :kewill
    end

    def customs_system shipment_data
      if shipment_data.is_a?(Hash)
        # Unwrap the hash if we're receiving the full shipment hash and not just the header data.
        if shipment_data["SHIPMENT"].present?
          shipment_data = shipment_data["SHIPMENT"]
        end

        return shipment_data["CustomsSystem"]
      else
        #Assume it's an invoice
        shipment_data.importer.system_code == system_code_prefix ? :kewill : :fenix
      end
    end

    def invoice_date shipment
      time = Time.zone.parse(shipment["ShipmentCompletionDate"].to_s+shipment["ShipmentCompletionTime"].to_s) rescue nil
      inbound_file.reject_and_raise("Failed to find ShipmentCompletionDate/Time.") if time.nil?
      time
    end

    def process_file? invoice, shipment
      invoice.last_exported_from_source.nil? || invoice.last_exported_from_source <= invoice_date(shipment)
    end

    def split_shipment data, max_invoice_length
      # You can only file 999 invoice lines electronically in Canada. WTF, eh?
      return [data] if data["DELIVERY_ITEMS"].length < max_invoice_length

      # So what we need to do is split the lines on the max length BUT we need to make sure
      # all the lines for a particular purchase order appear on the same shipment. So, if we're at 
      # line 997 and the next PO has 4 lines..we need to split the file at 997.
      all_files = []
      current_file_rows = []
      current_po_row_list = []
      current_po = nil

      do_swap_lambda = lambda do 
        new_shipment = {}
        new_shipment["SHIPMENT"] = data["SHIPMENT"].deep_dup
        # If we're splitting multiple files we need to add a file index to the ExternalId (used for invoice number) 
        # so that we're using a distinct invoice number for each split
        new_shipment["SHIPMENT"]["ExternalID"] = "#{new_shipment["SHIPMENT"]["ExternalID"]}-#{(all_files.length + 1).to_s.rjust(2, "0")}"
        
        new_shipment["DELIVERY_ITEMS"] = current_file_rows

        all_files << new_shipment
      end

      list_swap_lambda = lambda do |last_row|
        break if last_row && current_file_rows.length == 0 && current_po_row_list.length == 0

        # We have a new PO here...so we need to figure out what to do w/ the current po row list...
        # If the list can't be added to our current file rows, since it would make it too long, then create a new file
        if (current_file_rows.length + current_po_row_list.length > max_invoice_length)
          do_swap_lambda.call
          current_file_rows = current_po_row_list
        else
          # Append the contents of the po list to our current file list
          current_file_rows.push *current_po_row_list
        end

        do_swap_lambda.call if last_row
      end

      data["DELIVERY_ITEMS"].each_with_index do |item, index|
        po = item["SalesOrderNumber"].to_s.strip

        if current_po.nil? || current_po == po
          current_po = po if current_po.nil?
        else
          list_swap_lambda.call false

          # reset the current po list, since we got a new PO to deal with.
          current_po = po
          current_po_row_list = []
        end

        current_po_row_list << item
      end

      list_swap_lambda.call true

      all_files
    end

    def max_fenix_invoice_length
      999
    end

    def pars_threshold
      150
    end

    def generate_file_totals invoice
      data = HmShipmentData.new
      data.invoice_number = invoice.invoice_number
      data.invoice_date = invoice.invoice_date
      data.pars_number = invoice.customer_reference_number_2
      # The PARS data is supposed to be in KG, so make sure we convert it to that
      data.weight = convert_to_kg(invoice.gross_weight, invoice.gross_weight_uom).round

      # Never show that the weight is zero, just round it to one if it is.  The zero
      # has to do with the converting from grams to KG's.  This may happen in a case where the file has 1000 lines
      # and is split at 999 and the 1 line shipment has a weight < .5 KG.  Weight isn't THAT important, so we just
      # don't want to have the sheet say zero on it (since every product has some sort of weight.)
      if data.weight.nil? || data.weight.zero?
        data.weight = BigDecimal("1")
      end

      # For every unique PO number, count it as a single carton...for the time being, since cartons,
      # are not on the I2...we just have to guestimate the carton count.
      po_numbers = Set.new

      invoice.invoice_lines.each do |line|
        po_numbers << line.po_number unless line.po_number.blank?
      end

      data.cartons = po_numbers.size

      data
    end

    def convert_to_kg weight, uom
      return BigDecimal("0") if weight.nil?

      uom = uom.to_s.upcase
      return weight if ["KG", "KGS"].include? uom.to_s.upcase

      case uom
      when "KG", "KGS"
        weight
      when "G"
        weight / BigDecimal("1000")
      when "LB", "LBS"
        weight * BigDecimal("0.453592")
      else
        weight
      end
    end

    def extract_shipment_data xml
      shipment = {}
      # Just stay using the XML element names
      shipment["SHIPMENT"] = extract_xml_data_to_hash(xml)
      shipment["DELIVERY_ITEMS"] = extract_delivery_item_data(xml)
      
      if shipment["SHIPMENT"]
        sending_site = shipment["SHIPMENT"]["SendingSite"]
        shipment["SHIPMENT"]["CustomsSystem"] = case sending_site.to_s.upcase
          when "W068"
            :fenix
          when "W184"
            :kewill
          else
            inbound_file.reject_and_raise("Invalid SendingSite value found: '#{sending_site}'.  Unable to determine what system to forward shipment data to.")      
          end
      end

      shipment
    end

    # Because of the way we need to potentially split up the file data for canada into multiple
    # invoices, we're going to pull out the data in the file into a hash for each item, it will make it 
    # easier to work with.
    def extract_delivery_item_data xml
      delivery_items = []
      REXML::XPath.each(xml, "DELIVERY_ITEMS/DELIVERY_ITEM") do |item|
        delivery_items << extract_xml_data_to_hash(item)
      end

      delivery_items
    end

    def extract_xml_data_to_hash xml
      hash = {}
      xml.each_element do |el|
        # We don't want to walk the xml heirarchy here, so only extract data from elements without children
        next if el.has_elements?
        hash[el.name] = el.text
      end
      hash
    end

    def system_code_prefix
      "HENNE"
    end

    def product_importer
      @product_importer ||= Company.importers.where(system_code: system_code_prefix).first
      inbound_file.error_and_raise "No Company record found with system code '#{system_code_prefix}'." if @product_importer.nil?
      @product_importer
    end

    def importer shipment
      if fenix?(shipment)
        @importer ||= Company.importers.where(fenix_customer_number: "887634400RM0001").first
        inbound_file.error_and_raise "No Fenix importer record found with Tax ID 887634400RM0001." if @importer.nil?
        @importer
      else
        product_importer
      end
    end

    def parse_decimal v
      BigDecimal(v.to_s.strip)
    rescue
      BigDecimal("0")
    end

    def country_origin iso_code, kewill_system
      return nil if iso_code.blank?

      # The US code for Burma/Myanmaar is still BU, however, Geodis/H&M are sending MM.  We're just going to 
      # translate it to BU internally.
      if kewill_system && iso_code.to_s.upcase == "MM"
        iso_code = "BU"
      end

      @countries ||= Hash.new do |h, k|
        h[k] = Country.where(iso_code: k).first
      end

      @countries[iso_code]
    end

    def us
      @us ||= Country.where(iso_code: "US").first
      raise "US country not found." if @us.nil?
      @us
    end

    def ca
      @ca ||= Country.where(iso_code: "CA").first
      raise "Canada country not found." if @ca.nil?
      @ca
    end

    def email_canadian_files_to
      MailingList.where(system_code: "canada_h_m_i978_files_1").first
    end

    def email_us_files_to
      MailingList.where(system_code: "us_h_m_i978_files_1").first
    end

    def email_us_exception_files_to
      MailingList.where(system_code: "us_h_m_i978_exception_files_1").first
    end

    def email_pars_coversheet_to
      MailingList.where(system_code: "h_m_pars_coversheet_1").first
    end

    def email_unused_pars_to
      MailingList.where(system_code: "PARSNumbersNeeded").first
    end

    # There is a period of time when this i978 and the old i2 parser are running in parallel.  The i2 needs to take precedence in that situation
    # and the i978 should not generate any files nor should it utilize PARS numbers as the i2 is also doing all these things.  Once this
    # i978 becomes fully live (and the i2 is discontinued) then the Custom Feature string should be set and this parser will be the one generating
    # files.
    def primary_ca_import_parser?
      @is_primary_ca ||= MasterSetup.get.custom_feature?("H&M i978 CA Import Live")
    end

    def primary_us_import_parser?
      @is_primary_us ||= MasterSetup.get.custom_feature?("H&M i978 US Import Live")
    end

end; end; end; end