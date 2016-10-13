require 'open_chain/ftp_file_support'
require 'open_chain/fixed_position_generator'
require 'open_chain/xml_builder'

module OpenChain; module CustomHandler; module Vandegrift; class KewillCommercialInvoiceGenerator < OpenChain::FixedPositionGenerator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport

  CiLoadEntry ||= Struct.new(:file_number, :customer, :invoices)
  CiLoadInvoice ||= Struct.new(:invoice_number, :invoice_date, :invoice_lines, :non_dutiable_amount, :add_to_make_amount)
  CiLoadInvoiceLine ||= Struct.new(:part_number, :country_of_origin, :gross_weight, :pieces, :hts, :foreign_value, :quantity_1, :quantity_2, :po_number, :first_sale, :department, :spi, :non_dutiable_amount, :cotton_fee_flag, :mid, :cartons, :add_to_make_amount, :unit_price, :buyer_customer_number, :seller_mid)

  def initialize
    # Even if this is xml, all the string values still need to be converted to ASCII and numbers formatted without decimals, etc.
    super(numeric_pad_char: ' ', string_output_encoding: "ASCII", output_timezone: "America/New_York")
  end

  def generate_and_send_invoices file_number, commercial_invoices, opts = {}
    entry = CiLoadEntry.new(file_number, nil, [])
    commercial_invoices = Array.wrap(commercial_invoices)

    entry.customer = commercial_invoices.first.importer.alliance_customer_number
    commercial_invoices.each do |inv|
      invoice = CiLoadInvoice.new(inv.invoice_number, inv.invoice_date, [], nil, nil)
      entry.invoices << invoice

      inv.commercial_invoice_lines.each do |line|
        line.commercial_invoice_tariffs.each do |tar|
          l = CiLoadInvoiceLine.new
          l.po_number = line.po_number
          l.part_number = line.part_number
          l.pieces = line.quantity
          l.unit_price = line.unit_price
          l.country_of_origin = line.country_origin_code
          l.foreign_value = line.value
          l.first_sale = line.contract_amount
          l.department = line.department
          l.mid = line.mid

          l.hts = tar.hts_code
          l.quantity_1 = tar.classification_qty_1
          l.quantity_2 = tar.classification_qty_2
          # If gross weight is given in grams, we must convert it to KGS
          if opts[:gross_weight_uom].to_s.upcase == "G"
            l.gross_weight = (BigDecimal(tar.gross_weight.to_s) / BigDecimal("1000")).round(2)
          else
            l.gross_weight = tar.gross_weight
          end
          
          l.spi = tar.spi_primary
          
          invoice.invoice_lines << l
        end
      end
    end

    generate_and_send [entry]
  end

  def generate_and_send entries 
    entries.each do |entry|
      if entry.invoices.length > 0
        doc, shipments = build_base_xml
        generate_entry_xml(shipments, entry)

        Tempfile.open(["CI_Load_#{entry.file_number}_", ".xml"]) do |file|
          file.binmode
          write_xml doc, file
          file.rewind

          ftp_file file
        end
      end
    end
  end

  def ftp_credentials
    connect_vfitrack_net('to_ecs/ci_load_xml')
  end

  def generate_entry_xml element, entry
    ship = add_element(element, "ediShipment")
    header_list = add_element(ship, "EdiInvoiceHeaderList")

    entry.invoices.each do |invoice|
      header = add_element(header_list, "EdiInvoiceHeader")
      generate_header(header, entry, invoice, invoice.invoice_lines)

      if invoice.invoice_lines.length > 0
        lines = add_element(header, "EdiInvoiceLinesList")
        line_number = 0
        invoice.invoice_lines.each do |invoice_line|
          line = add_element(lines, "EdiInvoiceLines")
          generate_line line, entry, invoice, invoice_line, (line_number += 1)
        end
      end
    end

    nil
  end

    private 

    def build_base_xml
      doc, xml = build_xml_document "requests"
      add_element(xml, "password", "lk5ijl9")
      add_element(xml, "userID", "kewill_edi")
      request = add_element(xml, "request")
      add_element(request, "action", "KC")
      add_element(request, "category", "EdiShipment")
      add_element(request, "subAction", "CreateUpdate")
      kc_data = add_element(request, "kcData")
      edi_shipments = add_element(kc_data, "ediShipments")


      [xml, edi_shipments]
    end

    def generate_header parent, entry, invoice, lines
      add_element(parent, "manufacturerId", string(entry.file_number, 15, pad_string: false, exception_on_truncate: true))
      add_element(parent, "commInvNo", string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: true))
      add_element(parent, "dateInvoice", date(invoice.invoice_date)) unless invoice.invoice_date.nil?
      add_element(parent, "custNo", string(entry.customer, 10, pad_string: false, exception_on_truncate: true))
      add_element(parent, "nonDutiableAmt", number(invoice.non_dutiable_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(invoice.non_dutiable_amount)
      add_element(parent, "addToMakeAmt", number(invoice.add_to_make_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(invoice.add_to_make_amount)
      add_element(parent, "currency", "USD")
      add_element(parent, "exchangeRate", "1000000")

      # Sum the carton totals from the lines (for some reason qty on invoice has no decimal places)
      add_element(parent, "qty", number(lines.inject(BigDecimal("0")) {|sum, line| sum += (nonzero?(line.cartons) ? line.cartons : 0)}, 12, decimal_places: 0, strip_decimals: true, pad_string: false))
      # Always set the uom to be CTNS
      add_element(parent, "uom", "CTNS")

      nil
    end

    def generate_line parent, entry, invoice, line, counter
      add_element(parent, "manufacturerId", string(entry.file_number, 15, pad_string: false, exception_on_truncate: true))
      add_element(parent, "commInvNo", string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: true))
      add_element(parent, "commInvLineNo", (counter * 10))
      add_element(parent, "dateInvoice", date(invoice.invoice_date)) unless invoice.invoice_date.nil?
      add_element(parent, "custNo", string(entry.customer, 10, pad_string: false, exception_on_truncate: true))
      add_element(parent, "partNo", string(line.part_number, 30, pad_string: false, exception_on_truncate: true))
      add_element(parent, "countryOrigin", string(line.country_of_origin, 2, pad_string: false, exception_on_truncate: true)) unless line.country_of_origin.blank?
      add_element(parent, "weightGross", number(line.gross_weight, 12, pad_string: false)) if nonzero?(line.gross_weight)
      add_element(parent, "kilosPounds", "KG")
      add_element(parent, "qtyCommercial", number(line.pieces, 12, decimal_places: 3, strip_decimals: true, pad_string: false)) if nonzero?(line.pieces)
      add_element(parent, "uomCommercial", "PCS")
      add_element(parent, "uomVolume", "M3")
      add_element(parent, "unitPrice", number(line.unit_price, 15, decimal_places: 3, strip_decimals: true, pad_string: false)) if nonzero?(line.unit_price)
      add_element(parent, "tariffNo", string(line.hts.to_s.gsub(".", ""), 10, pad_string: false)) unless line.hts.blank?
      add_element(parent, "valueForeign", number(line.foreign_value, 13, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.foreign_value)
      add_element(parent, "qty1Class", number(line.quantity_1, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.quantity_1)
      add_element(parent, "qty2Class", number(line.quantity_2, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.quantity_2)
      add_element(parent, "purchaseOrderNo", string(line.po_number, 35, pad_string: false, exception_on_truncate: true)) unless line.po_number.blank?
      add_element(parent, "custRef", string(line.po_number, 35, pad_string: false, exception_on_truncate: true)) unless line.po_number.blank?
      add_element(parent, "contract", number(line.first_sale, 12, decimal_places: 2, strip_trailing_zeros: true, pad_string: false)) if nonzero?(line.first_sale)
      add_element(parent, "department", number(line.department, 6, decimal_places: 0, strip_decimals: true, pad_string: false)) if nonzero?(line.department)
      add_element(parent, "spiPrimary", string(line.spi, 2, pad_string: false)) unless line.spi.blank?
      add_element(parent, "nonDutiableAmt", number(line.non_dutiable_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.non_dutiable_amount)
      add_element(parent, "addToMakeAmt", number(line.add_to_make_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.add_to_make_amount)
      if ["Y", "YES", "TRUE", "1"].include?(line.cotton_fee_flag.to_s.upcase)
        add_element(parent, "exemptionCertificate", "999999999")
      end
      add_element(parent, "manufacturerId2", string(line.mid, 15, pad_string: false, exception_on_truncate: true)) unless line.mid.blank?
      add_element(parent, "cartons", number(line.cartons, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.cartons)

      seller_mid = get_seller_mid(line) unless line.seller_mid.blank?
      buyer_address = get_buyer(line) unless line.buyer_customer_number.blank?

      if seller_mid || buyer_address
        parties = add_element(parent, "EdiInvoicePartyList")
        add_seller_mid(parties, entry, invoice, counter, seller_mid) if seller_mid
        add_buyer(parties, entry, invoice, counter, buyer_address) if buyer_address
      end

      nil
    end

    def nonzero? val
      val.try(:nonzero?)
    end

    class MissingCiLoadDataError < StandardError
    end

    def get_seller_mid line
      # Use a cache, since more than likely the same MID is used for every single line...or at least re-used several times.
      @mids ||= Hash.new do |h, k|
        mid = ManufacturerId.where(mid: k).first
        h[k] = mid
      end
      
      mid = @mids[line.seller_mid]
      raise MissingCiLoadDataError, "No MID exists in VFI Track for '#{line.seller_mid}'." unless mid
      raise MissingCiLoadDataError, "MID '#{line.seller_mid}' is not an active MID." unless mid.active

      mid
    end

    def add_seller_mid parent, entry, invoice, counter, mid
      party = add_element(parent, "EdiInvoiceParty")
      add_element(party, "commInvNo", string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: true))
      add_element(party, "commInvLineNo", (counter * 10))
      add_element(party, "dateInvoice", date(invoice.invoice_date)) unless invoice.invoice_date.nil?
      add_element(party, "manufacturerId", string(entry.file_number, 15, pad_string: false, exception_on_truncate: true))
      add_element(party, "partiesQualifier","SE")
      add_element(party, "address1", string(mid.address_1, 95, pad_string: false, exception_on_truncate: true)) unless mid.address_1.blank?
      add_element(party, "address2", string(mid.address_2, 104, pad_string: false, exception_on_truncate: true)) unless mid.address_2.blank?
      add_element(party, "city", string(mid.city, 93, pad_string: false, exception_on_truncate: true)) unless mid.city.blank?
      add_element(party, "country", string(mid.country, 2, pad_string: false, exception_on_truncate: true)) unless mid.country.blank?
      add_element(party, "name", string(mid.name, 104, pad_string: false, exception_on_truncate: true)) unless mid.name.blank?
      add_element(party, "zip", string(mid.postal_code, 9, pad_string: false, exception_on_truncate: true)) unless mid.postal_code.blank?
      nil
    end

    def get_buyer line
      # We're going to allow users to specify the customer number and then optionally the customer address to utilize by 
      # passing the customer number (CUSTNO) and then putting a hyphen and the Kewill address number to use (defaulting to 1)
      # if not given.
      # CUSTNO -> Find Address for CUSTNO with a number 1.
      # CUSTNO-2 -> Find address for CUSTNO with a number 2.
      if line.buyer_customer_number =~ /(.*)-(\d+)$/
        cust_no = $1
        address_no = $2
      else
        cust_no = line.buyer_customer_number
        address_no = "1"
      end

      @addresses ||= Hash.new do |h, k|
        cust_no = k[0]
        address_no = k[1]

        h[k] = Address.joins(:company).where(companies: {alliance_customer_number: cust_no}).where(system_code: address_no).first
      end
      
      address = @addresses[[cust_no, address_no]]

      raise MissingCiLoadDataError, "No Customer Address # '#{address_no}' found for '#{cust_no}'." unless address

      address
    end

    def add_buyer parent, entry, invoice, counter, buyer
      party = add_element(parent, "EdiInvoiceParty")
      add_element(party, "commInvNo", string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: true))
      add_element(party, "commInvLineNo", (counter * 10))
      add_element(party, "dateInvoice", date(invoice.invoice_date)) unless invoice.invoice_date.nil?
      add_element(party, "manufacturerId", string(entry.file_number, 15, pad_string: false, exception_on_truncate: true))
      add_element(party, "partiesQualifier","BY")
      add_element(party, "address1", string(buyer.line_1, 95, pad_string: false, exception_on_truncate: true)) unless buyer.line_1.blank?
      add_element(party, "address2", string(buyer.line_2, 104, pad_string: false, exception_on_truncate: true)) unless buyer.line_2.blank?
      add_element(party, "city", string(buyer.city, 93, pad_string: false, exception_on_truncate: true)) unless buyer.city.blank?
      add_element(party, "country", string(buyer.country.iso_code, 2, pad_string: false, exception_on_truncate: true)) unless buyer.country.try(:iso_code).blank?
      add_element(party, "countrySubentity", string(buyer.state, 9, pad_string: false, exception_on_truncate: true)) unless buyer.state.blank?
      add_element(party, "custNo", string(buyer.company.alliance_customer_number, 10, pad_string: false, exception_on_truncate: true)) unless buyer.company.try(:alliance_customer_number).blank?
      add_element(party, "name", string(buyer.name, 104, pad_string: false, exception_on_truncate: true)) unless buyer.name.blank?
      add_element(party, "zip", string(buyer.postal_code, 9, pad_string: false, exception_on_truncate: true)) unless buyer.postal_code.blank?
      nil
    end

end; end; end; end;