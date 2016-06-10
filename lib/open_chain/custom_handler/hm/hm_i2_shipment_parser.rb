require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/csv_excel_parser'

module OpenChain; module CustomHandler; module Hm; class HmI2ShimentParser
  extend OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::CsvExcelParser

  def self.parse file, opts = {}
    new.parse(file)
  end

  def initialize 
    @cdefs = self.class.prep_custom_definitions [:class_customs_description]
  end

  def parse file_contents, forward_to_entry_system: true
    rows = foreach(file_contents, skip_blank_lines: true)
    system = determine_system(rows.first)
    # NOTE: the invoices we're creating here are NOT saved...we're just using the datastructure as a passthrough
    # for the Fenix / Kewill file transfers
    invoice = make_invoice(system, rows.first)
    rows.each do |row|
      set_invoice_line_info(system, invoice.commercial_invoice_lines.build, row)
    end

    set_totals(invoice)

    if forward_to_entry_system
      if system == :fenix
        OpenChain::CustomHandler::FenixNdInvoiceGenerator.generate invoice
      else
        # Send to Kewill Customs
        g = OpenChain::CustomHandler::KewillCommercialInvoiceGenerator.new
        g.generate_and_send_invoices nil, invoice
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
    invoice.importer = importer
    invoice.invoice_number = text_value(line[0])
    invoice.invoice_date = line[3].blank? ? nil : Time.zone.parse(line[3])
    
    invoice
  end

  def set_invoice_line_info system, i, line
    i.po_number = text_value(line[6])
    i.part_number = text_value(line[9])
    i.country_origin_code = text_value(line[12])
    i.quantity = decimal_value(line[13])
    # Unit Price is sent as cents
    i.unit_price = (decimal_value(line[28]).presence || 0) / 100
    i.customer_reference = text_value(line[19])

    i.line_number = decimal_value(line[7]).to_i

    hts, description = hts_and_description(system, i.part_number)
    i.commercial_invoice_tariffs.build hts_code: hts, tariff_description: description, gross_weight: decimal_value(line[17])
  end

  def set_totals invoice
    totals = Hash.new {|h, k| h[k] = BigDecimal("0") }
    invoice.commercial_invoice_lines.each do |line|
      line.commercial_invoice_tariffs.each do |tar|
        totals[:gross_weight] += tar.gross_weight if tar.gross_weight
      end
    end

    invoice.gross_weight = totals[:gross_weight].presence || 0
  end

  def file_reader file
    csv_reader StringIO.new(file), col_sep: ";"
  end

  def importer
    @importer ||= Company.importers.where(system_code: "HENNE").first
    raise "No importer record found with system code HENNE." if @importer.nil?
    @importer
  end

  def hts_and_description system, part_number
    product = Product.where(importer_id: importer.id, unique_identifier: "#{importer.system_code}-#{part_number}").first
    hts, description = nil
    if product
      classification = product.classifications.find {|c| c.country.try(:iso_code) == (system == :fenix ? "CA" : "US") }
      if classification
        # Tariff description is not sent to Kewill, so don't bother making the custom value lookup
        description = classification.custom_value(@cdefs[:class_customs_description]) if system == :fenix
        hts = classification.tariff_records.first.try(:hts_1)
      end
    end
    [hts, description]
  end

end; end; end; end;