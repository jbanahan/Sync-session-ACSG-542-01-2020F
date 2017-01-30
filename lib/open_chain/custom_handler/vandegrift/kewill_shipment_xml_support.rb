require 'open_chain/fixed_position_generator'
require 'open_chain/custom_handler/vandegrift/kewill_web_services_support'

module OpenChain; module CustomHandler; module Vandegrift; module KewillShipmentXmlSupport
  include OpenChain::CustomHandler::Vandegrift::KewillWebServicesSupport
  extend ActiveSupport::Concern

  # This is done so that every generator instance that includes this module can have the structs below
  # namespaced to their own class
  included do
    CiLoadEntry ||= Struct.new(:file_number, :customer, :invoices, :containers, :master_bill, :house_bill, :customer_reference, :vessel, :voyage, :carrier, :customs_ship_mode, :lading_port, :unlading_port, :est_arrival_date, :export_date, :est_departure_date, :unique_identifier)
    CiLoadContainer ||= Struct.new(:container_number, :seal_number)
    CiLoadInvoice ||= Struct.new(:invoice_number, :invoice_date, :invoice_lines, :non_dutiable_amount, :add_to_make_amount, :uom, :currency, :exchange_rate)
    CiLoadInvoiceLine ||= Struct.new(:part_number, :country_of_origin, :gross_weight, :pieces, :hts, :foreign_value, :quantity_1, :quantity_2, :po_number, :first_sale, :department, :spi, :non_dutiable_amount, :cotton_fee_flag, :mid, :cartons, :add_to_make_amount, :unit_price, :buyer_customer_number, :seller_mid)
  end

  def generate_entry_xml element, entry, add_entry_info: true
    keys = add_entry_info ? entry_keys(entry) : {}

    ship = add_element(element, "ediShipment")
    header_list = add_element(ship, "EdiInvoiceHeaderList")
    generate_shipment_header(header_list, entry, keys) if add_entry_info

    entry.invoices.each do |invoice|
      header = add_element(header_list, "EdiInvoiceHeader")
      generate_invoice_header(header, entry, invoice, invoice.invoice_lines, keys)

      if invoice.invoice_lines.length > 0
        lines = add_element(header, "EdiInvoiceLinesList")
        line_number = 0
        invoice.invoice_lines.each do |invoice_line|
          line = add_element(lines, "EdiInvoiceLines")
          generate_invoice_line line, entry, invoice, invoice_line, (line_number += 1), keys
        end
      end
    end

    nil
  end

  def g
    # Even if this is xml, all the string values still need to be converted to ASCII and numbers formatted without decimals, etc.
    @generator ||= OpenChain::FixedPositionGenerator.new(numeric_pad_char: ' ', string_output_encoding: "ASCII", output_timezone: "America/New_York")
  end

  def build_base_xml
    doc, kc_data = create_document category: "EdiShipment", subAction: "CreateUpdate"
    edi_shipments = add_element(kc_data, "ediShipments")

    [doc, edi_shipments]
  end

  def generate_shipment_header list, entry, keys
    parent = add_element(list, "EdiShipmentHeader")

    generate_key_data(parent, keys)
    add_element(parent, "fileNo", g.string(entry.file_number, 15, pad_string: false, exception_on_truncate: true))
    add_element(parent, "custNo", g.string(entry.customer, 10, pad_string: false, exception_on_truncate: true))

    add_element(parent, "custRef", g.string(entry.customer_reference, 35, pad_string: false))
    add_element(parent, "vesselAirlineName", g.string(entry.vessel, 20, pad_string: false))
    add_element(parent, "voyageFlightNo", g.string(entry.voyage, 10, pad_string: false))
    add_element(parent, "carrier", g.string(entry.carrier, 4, pad_string: false))
    add_element(parent, "mot", g.number(entry.customs_ship_mode, 2, decimal_places: 0, strip_decimals: true, pad_string: false))
    add_element(parent, "portLading", g.string(entry.lading_port, 5, pad_string: false))
    add_element(parent, "portDist", g.string(entry.unlading_port, 4, pad_string: false))
    add_element(parent, "dateEstArrival", g.date(entry.est_arrival_date))

    if (keys.keys - [:unique_identifier]).length > 0
      id = add_element(parent, "EdiShipmentIdList")
      generate_bills(id, bills, keys)
    end

    if entry.export_date || entry.est_departure_date
      list = add_element(parent, "EdiShipmentDatesList")
      generate_shipment_date(list, "1", entry.export_date, keys)
      generate_shipment_date(list, "688", entry.est_departure_date, keys)
    end

    if entry.containers.try(:length).to_i > 0
      containers = add_element(parent, "EdiContainersList")
      Array.wrap(entry.containers).each do |c|
        generate_container(containers, entry, c, keys)
      end
    end
    
  end

  def entry_keys entry
    raise MissingCiLoadDataError, "Unique Identifier or File Number must be set on all entry data sent to Kewill." if entry.unique_identifier.to_s.blank? && entry.file_number.to_s.blank?

    # Set the identifier to the file number if the id is blank.
    if entry.unique_identifier.blank? 
      entry.unique_identifier = entry.file_number.to_s
    end

    # kewill splits the master bill into the scac and number...which seems dumb, and also seems to use these values as the 
    # identifier for the shipment, which means that sub-elements like containers need to add these values to their elements
    data = {}

    data[:master_bill_scac], data[:master_bill] = chop_bill(entry.master_bill.to_s.strip) if !entry.master_bill.blank?
    data[:house_bill_scac], data[:house_bill] = chop_bill(entry.house_bill.to_s.strip) if !entry.house_bill.blank?
    data[:unique_identifier] = entry.unique_identifier

    data
  end

  def chop_bill bill
    if bill.length > 12
      [bill[0..3], bill[4..-1]]
    else
      [nil, bill]
    end
  end

  def generate_shipment_date parent, date_number, date, keys
    return unless date

    el = add_element(parent, "EdiShipmentDate")
    generate_key_data(el, keys)
    add_element(el, "tracingDateNo", date_number)
    add_element(el, "dateTracingShipment", g.date(date))
  end

  def generate_container parent, entry, container, keys
    c = add_element(parent, "EdiContainers")
    generate_key_data(c, keys)
    add_element(c, "noContainer", g.string(container.container_number, 15, pad_string: false))
    add_element(c, "sealNo", g.string(container.seal_number, 15, pad_string: false))
    add_element(c, "custNo", g.string(entry.customer, 10, pad_string: false))

  end

  def generate_bills parent, keys
    id = add_element(parent, "EdiShipmentId")
    add_element(id, "seqNo", "1")
    add_element(id, "scacHouse", g.string(keys[:house_bill_scac], 4, pad_string: false))
    add_element(id, "scac", g.string(keys[:master_bill_scac], 4, pad_string: false))
    generate_key_data(id, keys)
  end

  def generate_key_data parent, keys
    add_element(parent, "houseBill", g.string(keys[:house_bill], 12, pad_string: false, exception_on_truncate: true))
    add_element(parent, "masterBill", g.string(keys[:master_bill], 12, pad_string: false, exception_on_truncate: true))
    add_element(parent, "matchEntry", g.string(keys[:unique_identifier], 10, pad_string: false, exception_on_truncate: true))
  end

  def generate_invoice_header parent, entry, invoice, lines, keys
    generate_key_data(parent, keys) unless keys.blank?

    add_element(parent, "manufacturerId", g.string(entry.file_number, 15, pad_string: false, exception_on_truncate: true)) unless entry.file_number.nil?
    add_element(parent, "commInvNo", g.string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: true))
    add_element(parent, "dateInvoice", g.date(invoice.invoice_date)) unless invoice.invoice_date.nil?
    add_element(parent, "custNo", g.string(entry.customer, 10, pad_string: false, exception_on_truncate: true))
    add_element(parent, "nonDutiableAmt", g.number(invoice.non_dutiable_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(invoice.non_dutiable_amount)
    add_element(parent, "addToMakeAmt", g.number(invoice.add_to_make_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(invoice.add_to_make_amount)
    currency = (invoice.currency.to_s.blank? ? "USD" : invoice.currency)
    add_element(parent, "currency", g.string(currency, 3, pad_string: false))
    exchange_rate = invoice.exchange_rate.nil? && currency == "USD" ? BigDecimal("100") : invoice.exchange_rate
    add_element(parent, "exchangeRate", g.number(exchange_rate, 7, decimal_places: 4, strip_decimals: true)) if exchange_rate

    # Sum the carton totals from the lines (for some reason qty on invoice has no decimal places)
    add_element(parent, "qty", g.number(lines.inject(BigDecimal("0")) {|sum, line| sum += (nonzero?(line.cartons) ? line.cartons : 0)}, 12, decimal_places: 0, strip_decimals: true, pad_string: false))
    # Always set the uom to be CTNS if it's blank
    add_element(parent, "uom", g.string((invoice.uom.to_s.blank? ? "CTNS" : invoice.uom), 6, pad_string: false))

    nil
  end

  def generate_invoice_line parent, entry, invoice, line, counter, keys
    generate_key_data(parent, keys) unless keys.blank?

    add_element(parent, "manufacturerId", g.string(entry.file_number, 15, pad_string: false, exception_on_truncate: true))
    add_element(parent, "commInvNo", g.string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: true))
    add_element(parent, "commInvLineNo", (counter * 10))
    add_element(parent, "dateInvoice", g.date(invoice.invoice_date)) unless invoice.invoice_date.nil?
    add_element(parent, "custNo", g.string(entry.customer, 10, pad_string: false, exception_on_truncate: true))
    add_element(parent, "partNo", g.string(line.part_number, 30, pad_string: false, exception_on_truncate: true))
    add_element(parent, "countryOrigin", g.string(line.country_of_origin, 2, pad_string: false, exception_on_truncate: true)) unless line.country_of_origin.blank?
    add_element(parent, "weightGross", g.number(line.gross_weight, 12, pad_string: false)) if nonzero?(line.gross_weight)
    add_element(parent, "kilosPounds", "KG")
    add_element(parent, "qtyCommercial", g.number(line.pieces, 12, decimal_places: 3, strip_decimals: true, pad_string: false)) if nonzero?(line.pieces)
    add_element(parent, "uomCommercial", "PCS")
    add_element(parent, "uomVolume", "M3")
    add_element(parent, "unitPrice", g.number(line.unit_price, 15, decimal_places: 3, strip_decimals: true, pad_string: false)) if nonzero?(line.unit_price)
    add_element(parent, "tariffNo", g.string(line.hts.to_s.gsub(".", ""), 10, pad_string: false)) unless line.hts.blank?
    add_element(parent, "valueForeign", g.number(line.foreign_value, 13, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.foreign_value)
    add_element(parent, "qty1Class", g.number(line.quantity_1, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.quantity_1)
    add_element(parent, "qty2Class", g.number(line.quantity_2, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.quantity_2)
    add_element(parent, "purchaseOrderNo", g.string(line.po_number, 35, pad_string: false, exception_on_truncate: true)) unless line.po_number.blank?
    add_element(parent, "custRef", g.string(line.po_number, 35, pad_string: false, exception_on_truncate: true)) unless line.po_number.blank?
    add_element(parent, "contract", g.number(line.first_sale, 12, decimal_places: 2, strip_trailing_zeros: true, pad_string: false)) if nonzero?(line.first_sale)
    add_element(parent, "department", g.number(line.department, 6, decimal_places: 0, strip_decimals: true, pad_string: false)) if nonzero?(line.department)
    add_element(parent, "spiPrimary", g.string(line.spi, 2, pad_string: false)) unless line.spi.blank?
    add_element(parent, "nonDutiableAmt", g.number(line.non_dutiable_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.non_dutiable_amount)
    add_element(parent, "addToMakeAmt", g.number(line.add_to_make_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.add_to_make_amount)
    if ["Y", "YES", "TRUE", "1"].include?(line.cotton_fee_flag.to_s.upcase)
      add_element(parent, "exemptionCertificate", "999999999")
    end
    add_element(parent, "manufacturerId2", g.string(line.mid, 15, pad_string: false, exception_on_truncate: true)) unless line.mid.blank?
    add_element(parent, "cartons", g.number(line.cartons, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.cartons)

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
    val.to_f.try(:nonzero?)
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
    add_element(party, "commInvNo", g.string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: true))
    add_element(party, "commInvLineNo", (counter * 10))
    add_element(party, "dateInvoice", g.date(invoice.invoice_date)) unless invoice.invoice_date.nil?
    add_element(party, "manufacturerId", g.string(entry.file_number, 15, pad_string: false, exception_on_truncate: true))
    add_element(party, "partiesQualifier","SE")
    add_element(party, "address1", g.string(mid.address_1, 95, pad_string: false, exception_on_truncate: true)) unless mid.address_1.blank?
    add_element(party, "address2", g.string(mid.address_2, 104, pad_string: false, exception_on_truncate: true)) unless mid.address_2.blank?
    add_element(party, "city", g.string(mid.city, 93, pad_string: false, exception_on_truncate: true)) unless mid.city.blank?
    add_element(party, "country", g.string(mid.country, 2, pad_string: false, exception_on_truncate: true)) unless mid.country.blank?
    add_element(party, "name", g.string(mid.name, 104, pad_string: false, exception_on_truncate: true)) unless mid.name.blank?
    add_element(party, "zip", g.string(mid.postal_code, 9, pad_string: false, exception_on_truncate: true)) unless mid.postal_code.blank?
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
    add_element(party, "commInvNo", g.string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: true))
    add_element(party, "commInvLineNo", (counter * 10))
    add_element(party, "dateInvoice", g.date(invoice.invoice_date)) unless invoice.invoice_date.nil?
    add_element(party, "manufacturerId", g.string(entry.file_number, 15, pad_string: false, exception_on_truncate: true))
    add_element(party, "partiesQualifier","BY")
    add_element(party, "address1", g.string(buyer.line_1, 95, pad_string: false, exception_on_truncate: true)) unless buyer.line_1.blank?
    add_element(party, "address2", g.string(buyer.line_2, 104, pad_string: false, exception_on_truncate: true)) unless buyer.line_2.blank?
    add_element(party, "city", g.string(buyer.city, 93, pad_string: false, exception_on_truncate: true)) unless buyer.city.blank?
    add_element(party, "country", g.string(buyer.country.iso_code, 2, pad_string: false, exception_on_truncate: true)) unless buyer.country.try(:iso_code).blank?
    add_element(party, "countrySubentity", g.string(buyer.state, 9, pad_string: false, exception_on_truncate: true)) unless buyer.state.blank?
    add_element(party, "custNo", g.string(buyer.company.alliance_customer_number, 10, pad_string: false, exception_on_truncate: true)) unless buyer.company.try(:alliance_customer_number).blank?
    add_element(party, "name", g.string(buyer.name, 104, pad_string: false, exception_on_truncate: true)) unless buyer.name.blank?
    add_element(party, "zip", g.string(buyer.postal_code, 9, pad_string: false, exception_on_truncate: true)) unless buyer.postal_code.blank?
    nil
  end
end; end; end; end;