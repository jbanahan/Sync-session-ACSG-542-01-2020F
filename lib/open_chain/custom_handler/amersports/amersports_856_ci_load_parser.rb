require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'

module OpenChain; module CustomHandler; module AmerSports; class AmerSports856CiLoadParser < OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator
  extend OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/_amersports_856", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_amersports_856"]
  end

  def self.parse data, opts = {}
    data.force_encoding("Windows-1252")
    
    file_header = nil
    header = nil
    lines = []
    data.each_line do |line|
      if line.starts_with? "H0"
        if lines.length > 0
          self.delay.process_invoice(file_header, header, lines)
          file_header = nil
          header = nil
          lines = []
        end

        file_header = line
      elsif line.starts_with? "C0"
        if lines.length > 0
          self.delay.process_invoice(file_header, header, lines)
          header = nil
          lines = []
        end

        header = line
      elsif line.starts_with? "C1"
        lines << line
      end
    end

    if lines.length > 0
      self.delay.process_invoice(file_header, header, lines)
    end
  end

  # This exists mostly just as a way to delay processing for a part of the file.
  def self.process_invoice shipment_header, invoice_header, lines
    self.new.process_invoice(shipment_header, invoice_header, lines)
  end

  def process_invoice shipment_header, invoice_header, lines
    entry = CiLoadEntry.new
    importer_code = amer_codes(val(shipment_header[74..83]))
    
    # According to Joe H, we're not going to use this process for Precor files, so just ignore them
    # rather than generate them and junk up the output folder.
    return if importer_code == "PRECOR"

    imp = importer(importer_code)
    entry.customer = imp.alliance_customer_number
    entry.invoices = []
    invoice = CiLoadInvoice.new
    invoice.invoice_lines = []
    entry.invoices << invoice

    invoice.invoice_number = invoice_header[17..38].to_s.strip
    invoice.invoice_date = Date.strptime(invoice_header[39..46], "%Y%m%d") rescue nil

    country_origin = invoice_header[577..578]
    gross_weight = parse_decimal(invoice_header[557..568])
    cartons = parse_decimal(invoice_header[539..550])

    line_count = 0
    
    lines.each do |line|
      line_count += 1

      cil = CiLoadInvoiceLine.new
      invoice.invoice_lines << cil

      cil.country_of_origin = country_origin
      cil.part_number = part_number(imp, line)
      cil.po_number = val(line[532..566])
      cil.pieces = parse_decimal(line[452..464], implied_decimals: 2)

      tariff = find_tariff_number(imp, cil.part_number)

      # If the tariff is blank, then just use the # from the file, it's better than nothing and should
      # help them to key the info
      if tariff.blank?
        cil.hts = val(line[429..438])
      else
        cil.hts = tariff
      end

      cil.foreign_value = parse_decimal(line[439..451], implied_decimals: 2)

      # Since MOL only sends us carton count and gross weight at the invoice header level, 
      # only include it on the first line of the spreadsheet we're creating.
      if line_count == 1
        cil.cartons = cartons
        cil.gross_weight = gross_weight
      end
    end

    generate_xls_to_google_drive("AMERSPORTS CI Load/#{entry.invoices.first.try(:invoice_number)}.xls", entry)
  end

  def part_number importer, line
    pn = val(line[130..159])
    style = nil
    if importer.alliance_customer_number == "WILSON"
      # For wilson, use everything up to the first slash or space
      if pn =~ /^([^\/ ]+)[\/ ]/
        style = $1
      else
        style = pn
      end
    else
      # Everyone else..strip the first character and use the next 6 digits
      style = pn[1..6]
    end

    style
  end

  def val(v)
    v.to_s.strip
  end

  def parse_decimal value, implied_decimals: 0
    v = val(value)
    dec = v.to_f != 0 ? BigDecimal(v) : nil
    if dec && implied_decimals > 0
      dec = dec / (10 ** implied_decimals)
    end

    dec
  end

  def find_tariff_number importer, style
    p = Product.where(importer_id: importer.id, unique_identifier: "#{importer.system_code}-#{style}").first
    hts_code = nil
    if p
      us_class = p.classifications.where(country_id: us.id).includes(:tariff_records).first
      if us_class
        hts_code = us_class.tariff_records.first.try(:hts_1)
      end
    end

    hts_code
  end

  def us 
    @us ||= Country.where(iso_code: "US").first
    raise "Unable to find US country." unless @us
    @us
  end

  def amer_codes code
    case code.to_s.upcase
    when "SALOMON"
      "SALOMON"
    when "ATOMIC"
      "SALOMON"
    when "ARMADA"
      "SALOMON"
    when "WILSON"
      "WILSON"
    when "PRECOR"
      "PRECOR"
    when "MAVIC"
      "MAVIC"
    else
      raise "Invalid AMERSPORTS Importer code received: '#{code}'."
    end
  end

  def importer code
    imp ||= Company.importers.where(alliance_customer_number: code).first
    raise "Unable to find AmerSports importer account with code '#{code}'." unless imp
    imp
  end

end; end; end; end