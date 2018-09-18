require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/fenix_nd_invoice_generator'
require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'

module OpenChain; module CustomHandler; module EddieBauer; class EddieBauerCommercialInvoiceParser
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport
  extend OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/_eddie_invoice", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_eddie_invoice"]
  end

  def self.parse_file data, log, opts = {}
    rows = []
    # These SHOULD be 1 invoice per file, but lets just allow more than that since it's easy enough to do
    parser = self.new

    # Not recording log identifiers for this parser because these invoices aren't actually stored in VFI Track.
    # Logging could be easily done later on, if desired.
    log.company = parser.parts_importer

    # Disable quoting (or set the char to the bell char which we'll never see in the file),
    #they've disabled it themselves in the output now too
    data.force_encoding "Windows-1252"
    CSV.parse(data, col_sep: "|", quote_char: "\007") do |row|
      row = convert_to_utf8 row
      if "HDR" == row[0].to_s.upcase && rows.length > 0
        parser.process_and_send_invoice(rows, log)
        rows = []
      end

      rows << row
    end

    parser.process_and_send_invoice(rows, log) if rows.length > 0
    nil
  end

  def process_and_send_invoice rows, log
    country = import_country(rows.first, log)

    if country == "CA"
      invoice = process_ca_invoice_rows(rows)
      OpenChain::CustomHandler::FenixNdInvoiceGenerator.new.generate_and_send(invoice) unless invoice.nil?
    elsif country == "US"
      entry = process_us_invoice_rows(rows)
      generate_xls_to_google_drive("EDDIE CI Load/#{entry.invoices.first.try(:invoice_number)}.xls", entry)
    end

    nil
  end

  def generate_xls_to_google_drive drive_path, entry
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new.generate_xls_to_google_drive(drive_path, entry)
  end

  def import_country row, log
    c = row[22].to_s.upcase.strip
    if c == "US" 
      return "US"
    elsif c == "CA"
      return "CA"
    else
      log.reject_and_raise "Unexpected Import Country value received: '#{c}'."
    end
  end

  def process_ca_invoice_rows rows
    values = process_rows(rows)
    invoice = nil
    if values[:details].length > 0
      invoice = create_ca_invoice_header(values[:header], values[:party])

      rollup_ca_details(values[:details]).each {|detail| create_ca_invoice_detail(invoice, detail) }
    end

    invoice
  end

  def process_rows rows
    vals = {header: nil, details: [], party: nil}

    rows.each do |row|
      case row[0].to_s.upcase 
      when "HDR"
        vals[:header] = row
      when "DTL"
        vals[:details] << row
      when "PTY"
        vals[:party] = row
      end
    end

    vals
  end

  def process_us_invoice_rows rows
    values = process_rows(rows)
    entry = nil
    if values[:details].length > 0
      entry = create_us_invoice_header(values[:header])
      invoice = entry.invoices.first

      values[:details].each {|row| create_us_invoice_line(invoice, row)}
    end

    entry
  end

  def create_us_invoice_header header
    entry = CiLoadEntry.new nil, "EBCC"
    entry.invoices = []
    invoice = CiLoadInvoice.new
    entry.invoices << invoice
    invoice.invoice_number = v(header[3])
    invoice.invoice_date = parse_date(v(header[28]))
    invoice.invoice_lines = []

    entry
  end

  def create_us_invoice_line invoice, row
    line = CiLoadInvoiceLine.new
    line.part_number = style(v(row[5]))
    line.country_of_origin = v(row[35])
    line.pieces = BigDecimal(v(row[8]))
    line.hts = hts_number(line.part_number, us)
    line.unit_price = BigDecimal(v(row[22]))
    line.foreign_value = line.pieces * line.unit_price
    line.po_number = v(row[53])
    line.mid = v(row[7])
    line.seller_mid = line.mid
    line.buyer_customer_number = "EBCC"

    invoice.invoice_lines << line
  end

  def create_ca_invoice_header header, party_line
    h = CommercialInvoice.new
    h.importer = ca_importer
    h.invoice_number = v(header[3])
    h.invoice_date = parse_date(v(header[28]))
    h.currency = v(header[16])
    uom = v(header[49]).upcase
    if uom =~ /CARTON/ || uom =~ /CTN/
      h.total_quantity_uom = "CTN"
      h.total_quantity = v(header[48]).to_i
    end
    h.gross_weight = BigDecimal.new(v(header[44]))

    h.vendor = parse_party(party_line, 6)
    h.consignee = parse_party(party_line, 102)

    h
  end

  def rollup_ca_details detail_lines
    details = Hash.new do |h, k|
      h[k] = {}
    end

    detail_lines.each do |line|
      # Skip lines w/ blank styles
      next if v(line[5]).blank?

      style = style(v(line[5]))

      hts = hts_number(style, ca)

      desc = v(line[6]) + (v(line[57]).blank? ? "" : " #{v(line[57])}")
      key = rollup_ca_key(style, desc, hts, v(line[22]), v(line[34]))
      if details[key].blank?
        details[key] = {part_number: style, country_origin_code: v(line[35]),
                        quantity: BigDecimal(v(line[8])), unit_price: BigDecimal(v(line[22])),
                        po_number: v(line[53]), hts_code: hts, tariff_description: desc
        }
      else
        details[key][:quantity] += BigDecimal(v(line[8]))
      end
    end
    

    details.values
  end

  def rollup_ca_key part_number, description, hts, price, coo
    "#{style(part_number)}~~#{description}~~#{hts}~~#{price}~~#{coo}"
  end

  def create_ca_invoice_detail header, detail_hash
    line = header.commercial_invoice_lines.build
    line.part_number = detail_hash[:part_number]
    line.country_origin_code = detail_hash[:country_origin_code]
    line.quantity = detail_hash[:quantity]
    line.unit_price = detail_hash[:unit_price]
    line.po_number = detail_hash[:po_number]

    tariff = line.commercial_invoice_tariffs.build
    tariff.hts_code = detail_hash[:hts_code]
    tariff.tariff_description = detail_hash[:tariff_description]

    nil
  end

  def style part_number
    part_number = part_number.to_s

    # This regex matches skus of the format XXX-XXX-XXX-XXX with an optional trailing suffix.
    # For our entry purposes we only need the first 2 sections of the sku.
    # An optional trailing A/B suffix needs to be taken into account when it's present as well.
    if part_number =~ /([^-]+)-([^-]+)-([^-]+)-([^-]+)(?:-([^-]+))?/
      part_number = "#{$1}-#{$2}"
      part_number += $5 unless $5.blank?
    else
      part_number = part_number[0, 8]
    end

    part_number
  end

  def parse_date v
    Date.strptime(v.to_s, "%m/%d/%Y") rescue nil
  end

  def v val
    val.to_s.strip
  end

  def ca_importer
    @ca_imp ||= Company.importers.where(fenix_customer_number: "855157855RM0001").first
    @ca_imp
  end

  def hts_number(part_number, country)
    part = Product.where(unique_identifier: "#{parts_importer.system_code}-#{part_number}").first
    part ? part.hts_for_country(country).first : nil
  end

  def parts_importer
    @parts_imp ||= Company.where(system_code: "EDDIE").first
    @parts_imp
  end

  def ca 
    @canada ||= Country.where(iso_code: "CA").first
  end

  def us 
    @usa ||= Country.where(iso_code: "US").first
  end

  def parse_party  party_line, starting_index
    c = Company.new
    c.name = v(party_line[starting_index])
    a = c.addresses.build
    a.line_1 = v(party_line[starting_index + 5])
    a.line_2 = v(party_line[starting_index + 6])
    a.city = v(party_line[starting_index + 9])
    a.state = v(party_line[starting_index + 10])
    a.postal_code = v(party_line[starting_index + 11])

    c
  end

  def self.convert_to_utf8 row
    row.map {|v| v.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") }
  end

end; end; end; end