require 'open_chain/fixed_position_generator'
require 'open_chain/custom_handler/vandegrift/kewill_web_services_support'

module OpenChain; module CustomHandler; module Vandegrift; module KewillShipmentXmlSupport
  include OpenChain::CustomHandler::Vandegrift::KewillWebServicesSupport
  extend ActiveSupport::Concern

  CI_LOAD_DATE_CODES ||= {
    est_arrival_date: "dateEstArrival",
    export_date: "1"
  }

  # UOM
  #  CTNS = Cartons
  #  M3 = Cubic Meters
  #  KG = Kilogram

  # The included here is done so that every generator instance that includes this module can have the structs below
  # namespaced to their own class
  included do
    CiLoadEntry ||= Struct.new(:file_number, :customer, :invoices, :containers, :bills_of_lading, :dates, :edi_identifier, :customer_reference, :vessel, :voyage, :carrier, :customs_ship_mode, :lading_port, :unlading_port, :pieces, :pieces_uom, :goods_description, :weight_kg, :consignee_code, :ultimate_consignee_code, :country_of_origin, :country_of_export)
    CiLoadEdiIdentifier ||= Struct.new(:master_bill, :house_bill, :sub_bill, :sub_sub_bill, :scac)
    # code is the symbol matching to the key above in the CI_LOAD_DATE_CODES constant
    CiLoadEntryDate ||= Struct.new(:code, :date)
    CiLoadBillsOfLading ||= Struct.new(:master_bill, :house_bill, :sub_bill, :sub_sub_bill, :pieces, :pieces_uom)
    CiLoadContainer ||= Struct.new(:container_number, :seal_number, :size, :description, :pieces, :pieces_uom, :weight_kg, :container_type)
    CiLoadInvoice ||= Struct.new(:invoice_number, :invoice_date, :invoice_lines, :non_dutiable_amount, :add_to_make_amount, :uom, :currency, :exchange_rate, :file_number)
    CiLoadInvoiceLine ||= Struct.new(:tariff_lines, :part_number, :country_of_origin, :country_of_export, :gross_weight, :pieces, :pieces_uom, :hts, :foreign_value, :quantity_1, :uom_1, :quantity_2, :uom_2, :po_number, :first_sale, :department, :spi, :non_dutiable_amount, :cotton_fee_flag, :mid, :cartons, :add_to_make_amount, :unit_price, :unit_price_uom, :buyer_customer_number, :seller_mid, :spi2, :line_number, :charges, :related_parties, :description, :container_number, :ftz_quantity, :ftz_zone_status, :ftz_priv_status_date)
    CiLoadInvoiceTariff ||= Struct.new(:hts, :gross_weight, :spi, :spi2, :foreign_value, :quantity_1, :uom_1, :quantity_2, :uom_2)
  end

  # Generate XML from data presented via the structs above.
  # If add_entry_info is true, then the XML will look for and generate shipment level data in Kewill
  # The standard "CI Load" spreadsheet that is done through the organization does NOT include entry data, for
  # it the add_entry_info flag should be false.
  def generate_entry_xml entry, add_entry_info: true
    doc, shipments = build_base_xml

    entry_identifier = add_entry_info ? generate_entry_identifier(entry) : nil

    if add_entry_info
      invoice_parent = generate_shipment_header(shipments, entry, entry_identifier)
    else
      invoice_parent = add_element(shipments, "ediShipment")
    end

    if Array.wrap(entry.invoices).length > 0
      header_list = add_element(invoice_parent, "EdiInvoiceHeaderList")

      Array.wrap(entry.invoices).each do |invoice|
        
        header = add_element(header_list, "EdiInvoiceHeader")
        generate_invoice_header(header, entry, invoice, invoice.invoice_lines, entry_identifier)

        if invoice.invoice_lines.length > 0
          lines = add_element(header, "EdiInvoiceLinesList")
          line_number = 0
          invoice.invoice_lines.each do |invoice_line|
            line = add_element(lines, "EdiInvoiceLines")
            generate_invoice_line line, entry, invoice, invoice_line, (line_number += 1), entry_identifier
          end
        end
      end
    end

    doc
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

  def generate_shipment_header shipment_element, entry, edi_identifier
    parent = add_element(shipment_element, "ediShipment")

    generate_identifier_data(parent, edi_identifier)
    add_element(parent, "fileNo", g.string(entry.file_number, 15, pad_string: false, exception_on_truncate: true))
    add_element(parent, "custNo", g.string(entry.customer, 10, pad_string: false, exception_on_truncate: true))

    add_element(parent, "custRef", g.string(entry.customer_reference, 35, pad_string: false))
    add_element(parent, "vesselAirlineName", g.string(entry.vessel, 20, pad_string: false))
    add_element(parent, "voyageFlightNo", g.string(entry.voyage, 10, pad_string: false))
    # This is just some weirdness so that Kewill doesn't generate a secondary scac-less master bill record
    add_element(parent, "scac", g.string(edi_identifier.scac, 4, pad_string:false)) unless edi_identifier.scac.blank?
    add_element(parent, "carrier", g.string(entry.carrier, 4, pad_string: false))
    add_element(parent, "mot", g.number(entry.customs_ship_mode, 2, decimal_places: 0, strip_decimals: true, pad_string: false))
    add_element(parent, "portLading", g.string(entry.lading_port, 5, pad_string: false))
    add_element(parent, "portDist", g.string(entry.unlading_port, 4, pad_string: false))

    # This is here to counteract some stupid bug or loading protocol in Kewill that we haven't figured out.  If you have multiple Master Bills, the quantity on the shipment
    # carries to the first master bill record (for some reason).  So, if you have multiple bills, we can't put the total piece count for the shipment here,
    # as it will push down to the master bill record.  Instead we'll put the first master bill record's piece count here and let it push down, the user
    # will then have to key the total - REALLY stupid.
    skip_first_bol_pieces = false
    if false #Array.wrap(entry.bills_of_lading).length > 1 && entry.bills_of_lading.first.try(:pieces).to_i > 0
      bill = entry.bills_of_lading.first
      add_element(parent, "pieceCount", g.number(bill.pieces, 12, decimal_places: 0, strip_decimals: true, pad_string: false))
      add_element(parent, "uom", g.string(bill.pieces_uom, 6, pad_string: false))
      #skip_first_bol_pieces = true
    else
      add_element(parent, "pieceCount", g.number(entry.pieces, 12, decimal_places: 0, strip_decimals: true, pad_string: false))
      add_element(parent, "uom", g.string(entry.pieces_uom, 6, pad_string: false))
    end
    
    add_element(parent, "descOfGoods", g.string(entry.goods_description, 70, pad_string: false))

    if entry.weight_kg && entry.weight_kg > 0
      add_element(parent, "weightGross", g.number(entry.weight_kg, 12, decimal_places: 0, pad_string: false))
      add_element(parent, "uomWeight", "KG")
    end

    add_element(parent, "consignee", g.string(entry.consignee_code, 10, pad_string: false))
    add_element(parent, "ultimateConsignee", g.string(entry.ultimate_consignee_code, 10, pad_string: false))
    add_element(parent, "countryOrigin", g.string(entry.country_of_origin, 2, pad_string: false, exception_on_truncate: true)) unless entry.country_of_origin.blank?
    add_element(parent, "countryExport", g.string(entry.country_of_export, 2, pad_string: false, exception_on_truncate: true)) unless entry.country_of_export.blank?
    

    generate_bills(parent, entry, edi_identifier, skip_first_bol_pieces)
    generate_entry_dates(parent, entry, edi_identifier)
    generate_containers(parent, entry, edi_identifier)
    
    parent
  end

  def generate_entry_dates parent, entry, edi_identifier
    list = nil
    Array.wrap(entry.dates).each do |date|
      code = CI_LOAD_DATE_CODES[date.code]
      # If the code is strictly numeric, then it needs to be added as an EdiShipmentDate element (.ie tracing date record in Kewill parlance)
      # If it's an element name, then add directly to the ediShipment element (not sure why some dates are elements and others are EdiShipmentDate)
      if code =~ /^\d+$/
        list ||= add_element(parent, "EdiShipmentDatesList")
        generate_shipment_date(list, code, date.date, edi_identifier)
      else
        add_element(parent, code, g.date(date.date))
      end
    end
  end

  def generate_containers parent, entry, edi_identifier
    if Array.wrap(entry.containers).length > 0
      containers = add_element(parent, "EdiContainersList")
      Array.wrap(entry.containers).each do |c|
        generate_container(containers, entry, c, edi_identifier)
      end
    end
  end

  def generate_bills(parent, entry, edi_identifier, skip_first_bol_pieces)
    if Array.wrap(entry.bills_of_lading).length > 0
      id_list = add_element(parent, "EdiShipmentIdList")

      Array.wrap(entry.bills_of_lading).each_with_index do |bill_of_lading, index|
        generate_shipment_id(id_list, bill_of_lading, edi_identifier, (index + 1), skip_first_bol_pieces)
      end
      
    end
  end

  def generate_entry_identifier entry
    # The identifier is data that will be used in the Kewill EDI tables to uniquely identify and tie all the shipment/invoice records together onto a single load when
    # pulled onto a shipment.  We're providing two ways to generate them...generate the CiLoadIdentifier record directly, or the data from the
    # FIRST CiLoadBillOfLading will be utilized.

    identifier = entry.edi_identifier
    if identifier.nil?
      bills = Array.wrap(entry.bills_of_lading)
      raise MissingCiLoadDataError, "At least one Bill of Lading record must be present for all entry data sent to Kewill." if bills.length == 0

      # Use the first bill of lading and generate an identifier from it..
      bill_of_lading = bills.first
      identifier = CiLoadEdiIdentifier.new
      if !bill_of_lading.master_bill.blank?
        scac, bol = chop_bill(bill_of_lading.master_bill.to_s.strip)
        identifier.scac = scac
        identifier.master_bill = bol
      end

      identifier.house_bill = chop_bill(bill_of_lading.house_bill.to_s.strip)[1] if !bill_of_lading.house_bill.blank?
      identifier.sub_bill = chop_bill(bill_of_lading.sub_bill.to_s.strip)[1] if !bill_of_lading.sub_bill.blank?
      identifier.sub_sub_bill = chop_bill(bill_of_lading.sub_sub_bill.to_s.strip)[1] if !bill_of_lading.sub_sub_bill.blank?
    else
      raise MissingCiLoadDataError, "At least one Edi Identifier value must be present." if identifier.master_bill.blank? && identifier.house_bill.blank? && identifier.sub_bill.blank? && identifier.sub_sub_bill.blank?
    end

    identifier
  end

  def chop_bill bill
    if bill.to_s.length > 12
      [bill[0..3], bill[4..-1]]
    else
      [nil, bill]
    end
  end

  def generate_shipment_date parent, date_number, date, edi_identifier
    return unless date

    el = add_element(parent, "EdiShipmentDates")
    generate_identifier_data(el, edi_identifier)
    add_element(el, "tracingDateNo", date_number)
    add_element(el, "dateTracingShipment", g.date(date))
  end

  def generate_container parent, entry, container, edi_identifier
    c = add_element(parent, "EdiContainers")
    generate_identifier_data(c, edi_identifier)
    add_element(c, "noContainer", g.string(container.container_number, 15, pad_string: false))
    add_element(c, "sealNo", g.string(container.seal_number, 15, pad_string: false))
    add_element(c, "custNo", g.string(entry.customer, 10, pad_string: false))
    add_element(c, "contSize", g.string(container.size, 7, pad_string: false))
    add_element(c, "descContent1", g.string(container.description, 40, pad_string: false))
    add_element(c, "containerType", g.string(container.container_type, 5, pad_string: false))
    # Pieces and UOM must both be present
    if container.pieces.to_i > 0
      raise "Container #{container.container_number} must have a Pieces UOM value present if any pieces are given." if container.pieces_uom.blank?

      add_element(c, "pieces", container.pieces.to_i)
      add_element(c, "uom", g.string(container.pieces_uom, 6, pad_string: false))
    end

    if container.weight_kg && container.weight_kg.to_d > 0
      add_element(c, "weight", g.number(container.weight_kg, 12, decimal_places: 0, pad_string: false))
      add_element(c, "uomWeight", "KG")
    end

  end

  def generate_shipment_id parent, bol, edi_identifier, sequence, skip_first_bol_pieces
    id = add_element(parent, "EdiShipmentId")
    add_element(id, "seqNo", sequence)
    generate_identifier_data(id, edi_identifier)

    # Because Kewill, in their not-so-infinite wisdom, used houseBill/MasterBill as the unique identifier to tie
    # all this data together in the EDI system of the Customs Management system...if you actually want to use
    # multiple bills of lading...you need to use fields called MASTER_BILL_ADDL and HOUSE_BILL_ADDL
    # we're going to assume that if the sequence is > 1 then we're dealing with additional bills
    
    scac, bill = chop_bill(bol.master_bill)
    add_element(id, "scac", g.string(scac, 4, pad_string: false))
    add_element(id, "masterBillAddl", g.string(bill, 12, pad_string: false))
    scac, bill = chop_bill(bol.house_bill)
    add_element(id, "scacHouse", g.string(scac, 4, pad_string: false))
    add_element(id, "houseBillAddl", g.string(bill, 12, pad_string: false))

    *, sub_bill = chop_bill(bol.sub_bill)
    add_element(id, "subBillAddl", g.string(sub_bill, 12, pad_string: false))
    *, sub_sub_bill = chop_bill(bol.sub_sub_bill)
    add_element(id, "subSubBillAddl", g.string(sub_sub_bill, 12, pad_string: false))

    # We skip the first qty sometimes as a workaround for a "bug" in Kewill loading quantities to 
    # master bill records
    # if (sequence != 1 || !skip_first_bol_pieces) && bol.pieces.to_i > 0
    #   add_element(id, "qty", g.number(bol.pieces, 12, decimal_places: 0, pad_string: false))
    #   add_element(id, "uom", g.string(bol.pieces_uom, 6, pad_string: false))
    # end

    add_element(id, "qty", g.number(bol.pieces, 12, decimal_places: 0, pad_string: false))
    add_element(id, "uom", g.string(bol.pieces_uom, 6, pad_string: false))
  end

  def generate_identifier_data parent, identifier
    # Allow truncating the master bill, this is mostly brought on by the fact that there are 1 or 2 shipping companies that 
    # now use 13 character masterbills, and Kewill's edi only allows 12 chars (dumb).
    add_element(parent, "houseBill", g.string(identifier.house_bill, 12, pad_string: false)) unless identifier.house_bill.blank?
    add_element(parent, "masterBill", g.string(identifier.master_bill, 12, pad_string: false))
    add_element(parent, "subBill", g.string(identifier.sub_bill, 12, pad_string: false)) unless identifier.sub_bill.blank?
    add_element(parent, "subSubBill", g.string(identifier.sub_sub_bill, 12, pad_string: false)) unless identifier.sub_sub_bill.blank?
  end

  def generate_invoice_header parent, entry, invoice, lines, edi_identifier
    generate_identifier_data(parent, edi_identifier) unless edi_identifier.nil?

    add_file_number(parent, entry, invoice)
    add_element(parent, "commInvNo", g.string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: false))
    add_element(parent, "dateInvoice", g.date(invoice.invoice_date)) unless invoice.invoice_date.nil?
    add_element(parent, "custNo", g.string(entry.customer, 10, pad_string: false, exception_on_truncate: true))
    add_element(parent, "nonDutiableAmt", g.number(invoice.non_dutiable_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(invoice.non_dutiable_amount)
    add_element(parent, "addToMakeAmt", g.number(invoice.add_to_make_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(invoice.add_to_make_amount)
    currency = (invoice.currency.to_s.blank? ? "USD" : invoice.currency)
    add_element(parent, "currency", g.string(currency, 3, pad_string: false))
    exchange_rate = invoice.exchange_rate.nil? && currency == "USD" ? BigDecimal("1") : invoice.exchange_rate
    add_element(parent, "exchangeRate", g.number(exchange_rate, 7, decimal_places: 6, strip_decimals: true).strip) if exchange_rate

    # Sum the carton totals from the lines (for some reason qty on invoice has no decimal places)
    add_element(parent, "qty", g.number(lines.inject(BigDecimal("0")) {|sum, line| sum += (nonzero?(line.cartons) ? line.cartons : 0)}, 12, decimal_places: 0, strip_decimals: true, pad_string: false))
    # Always set the uom to be CTNS if it's blank
    add_element(parent, "uom", g.string((invoice.uom.to_s.blank? ? "CTNS" : invoice.uom), 6, pad_string: false))

    nil
  end

  def generate_invoice_line parent, entry, invoice, line, counter, edi_identifier
    generate_identifier_data(parent, edi_identifier) unless edi_identifier.nil?

    invoice_line_number = counter * 10

    add_invoice_line_key_fields(parent, entry, invoice, invoice_line_number)

    add_element(parent, "custNo", g.string(entry.customer, 10, pad_string: false, exception_on_truncate: true))
    add_element(parent, "partNo", g.string(line.part_number, 30, pad_string: false, exception_on_truncate: true))
    add_element(parent, "countryOrigin", g.string(line.country_of_origin, 2, pad_string: false, exception_on_truncate: true)) unless line.country_of_origin.blank?
    add_element(parent, "countryExport", g.string(line.country_of_export, 2, pad_string: false, exception_on_truncate: false)) unless line.country_of_export.blank?
    add_element(parent, "qtyCommercial", g.number(line.pieces, 12, decimal_places: 3, strip_decimals: true, pad_string: false)) if nonzero?(line.pieces)
    add_element(parent, "uomCommercial", g.string((line.pieces_uom.blank? ? "PCS" : line.pieces_uom), 5, pad_string: false, exception_on_truncate: false))
    add_element(parent, "uomVolume", "M3")
    add_element(parent, "unitPrice", g.number(line.unit_price, 15, decimal_places: 3, strip_decimals: true, pad_string: false)) if nonzero?(line.unit_price)
    add_element(parent, "uomUnitPrice", g.string(line.unit_price_uom, 6, pad_string: false, exception_on_truncate: false)) unless line.unit_price_uom.blank?
    add_element(parent, "purchaseOrderNo", g.string(line.po_number, 35, pad_string: false, exception_on_truncate: true)) unless line.po_number.blank?
    add_element(parent, "custRef", g.string(line.po_number, 35, pad_string: false, exception_on_truncate: true)) unless line.po_number.blank?
    add_element(parent, "contract", g.number(line.first_sale, 12, decimal_places: 2, strip_trailing_zeros: true, pad_string: false)) if nonzero?(line.first_sale)
    add_element(parent, "department", g.number(line.department, 6, decimal_places: 0, strip_decimals: true, pad_string: false)) if nonzero?(line.department)
    add_element(parent, "nonDutiableAmt", g.number(line.non_dutiable_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.non_dutiable_amount)
    add_element(parent, "addToMakeAmt", g.number(line.add_to_make_amount, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.add_to_make_amount)

    # This looks a little strange, but there's a logic here...The cotton fee field is only used to indicate if there's an exemption to
    # the cotton fee (meaning the cotton fee doesn't apply to a textile item).  In that case, the N means "No, there isn't a cotton fee."
    # or 1 is also acceptable because that's actually the certificate number used to indicate that the cotton fee applies.
    # That's why 1 / N are the only accepted values.
    if ["1", "N"].include?(line.cotton_fee_flag.to_s.upcase)
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

    add_element(parent, "detailLineNo", line.line_number.to_i) unless line.line_number.blank?
    add_element(parent, "chargesAmt", g.number(line.charges, 11, decimal_places: 2, pad_string: false)) if nonzero?(line.charges)
    add_element(parent, "relatedParties", g.string((true?(line.related_parties) ? "Y" : "N"), 1, pad_string: false, exception_on_truncate: false)) unless line.related_parties.nil?
    add_element(parent, "ftzQuantity", g.number(line.ftz_quantity, 10, pad_string: false, decimal_places: 0)) if nonzero?(line.ftz_quantity)
    add_element(parent, "ftzZoneStatus", g.string(line.ftz_zone_status, 1, pad_string: false, exception_on_truncate: true)) unless line.ftz_zone_status.blank?
    add_element(parent, "ftzPrivStatusDate", g.date(line.ftz_priv_status_date)) unless line.ftz_priv_status_date.blank?   
    
    add_element(parent, "descr", g.string(line.description, 40, pad_string: false)) unless line.description.blank?
    add_element(parent, "noContainer", g.string(line.container_number, 15, pad_string: false)) unless line.container_number.blank?


    tariff_lines = Array.wrap(line.tariff_lines)

    # In Kewill's EDI system you can send simple tariff data along w/ the commercial invoice line without having to send
    # child tariff line records.  However, if you do want to send multiple lines...then you need to send the child records.
    # We'll handle both ways...at least partially due to the handling of the special tariff cross references that allow for
    # adding special tariffs on the fly.
    if tariff_lines.length > 0
      special_tariff_line = nil
      special_tariff_lines = []
      tariff_lines.each do |tariff|
        special_tariffs = additional_tariff_number(invoice.invoice_date, line.country_of_origin, tariff.hts)
        special_tariffs.each_with_index do |special_tariff, idx|
          special_tariff_line = tariff.dup
          special_tariff_line.hts = special_tariff.special_hts_number
          # Special tariff lines don't carry any actual value
          special_tariff_line.foreign_value = nil
          special_tariff_lines << special_tariff_line
        end
      end

      tariff_lines.insert(0, *special_tariff_lines) unless special_tariff_lines.blank?
    else
      special_tariffs = additional_tariff_number(invoice.invoice_date, line.country_of_origin, line.hts)
      tariff_lines = []
      special_tariffs.each_with_index do |special_tariff, idx|
        # Special tariff lines don't carry any actual value
        tariff_lines << convert_invoice_line_to_tariff(line, hts: special_tariff.special_hts_number, copy_value: false)
      end

      # We don't need to break out invoice lines to tariff lines if we only have a single tariff line (.ie
      # there's no special tariffs being added)
      tariff_lines << convert_invoice_line_to_tariff(line, copy_value: true) unless tariff_lines.blank?
    end

    if tariff_lines.blank?
      add_tariff_fields(parent, line)
    else
      tariff_counter = 0
      tariff_class_element = add_element(parent, "EdiInvoiceTariffClassList")
      tariff_lines.each do |tariff|
        tariff_class = add_element(tariff_class_element, "EdiInvoiceTariffClass")
        add_invoice_tariff_line(tariff_class, entry, invoice, invoice_line_number, tariff, (tariff_counter += 1))
      end
    end
    
    nil
  end

  def add_invoice_line_key_fields parent, entry, invoice, invoice_line_number
    file_number = invoice.file_number.presence || entry.file_number
    add_element(parent, "manufacturerId", g.string(file_number, 15, pad_string: false, exception_on_truncate: true))
    add_element(parent, "commInvNo", g.string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: false))
    add_element(parent, "dateInvoice", g.date(invoice.invoice_date)) unless invoice.invoice_date.nil?
    add_element(parent, "commInvLineNo", invoice_line_number)
    nil
  end

  def add_invoice_tariff_line parent, entry, invoice, invoice_line_number, tariff, tariff_line_no
    add_invoice_line_key_fields(parent, entry, invoice, invoice_line_number)
    add_tariff_fields(parent, tariff, tariff_line_no: tariff_line_no)
    nil
  end

  def add_tariff_fields parent, line, tariff_line_no: nil
    add_element(parent, "tariffLineNo", tariff_line_no) unless tariff_line_no.nil?
    add_element(parent, "tariffNo", g.string(line.hts.to_s.gsub(".", ""), 10, pad_string: false)) unless line.hts.blank?
    add_element(parent, "weightGross", g.number(line.gross_weight, 12, pad_string: false)) if nonzero?(line.gross_weight)
    add_element(parent, "kilosPounds", "KG")
    add_element(parent, "valueForeign", g.number(line.foreign_value, 13, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.foreign_value)
    add_element(parent, "spiPrimary", g.string(line.spi, 2, pad_string: false)) unless line.spi.blank?
    add_element(parent, "spiSecondary", g.string(line.spi2, 2, pad_string: false)) unless line.spi2.blank?
    add_element(parent, "qty1Class", g.number(line.quantity_1, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.quantity_1)
    add_element(parent, "uom1Class", g.string(line.uom_1, 3, pad_string: false)) unless line.uom_1.blank?
    add_element(parent, "qty2Class", g.number(line.quantity_2, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.quantity_2)
    add_element(parent, "uom2Class", g.string(line.uom_2, 3, pad_string: false)) unless line.uom_2.blank?
    nil
  end

  def convert_invoice_line_to_tariff line, hts: nil, copy_value: false
    # The attributes we're using between the invoice line and the tariff line are actually (currently) identical 
    # So, we're not actually going to do anything aside from cloning the line itself
    new_line = line.dup
    new_line.foreign_value = nil unless copy_value

    if hts
      new_line.hts = hts
    end

    new_line
  end

  def nonzero? val
    val.to_f.try(:nonzero?)
  end

  def add_file_number parent, entry, invoice
    # Prefer the file number from invoice first and then entry, if present
    # (which, for the way Kewill is set up for us, file number is really just a unique identifier value for the invoice)
    # So, there's a few cases where on a full shipment where an invoice might appear on multiple shipments (bols) and Kewill
    # will reject them due to a unique constraint over file_number (manufacturerId), invoice number, invoice date.
    # So for those cases, we're actually using the file_number as some unique value to work around the unique constraint.
    file_number = invoice.file_number.presence || (entry.file_number.presence || nil)
    add_element(parent, "manufacturerId", g.string(file_number, 15, pad_string: false, exception_on_truncate: true)) unless file_number.blank?
    nil
  end

  def true? val
    ["Y", "YES", "TRUE", "1"].include?(val.to_s.upcase)
  end

  def split_string string, segment_length, max_splits
    return nil if string.blank?
    return [string] if string.length < segment_length

    components = []
    
    # copy the string since we're slicing it below
    split_string = string.dup
    max_splits.times do 
      if split_string.length < segment_length
        components << split_string
        break
      else
        components << split_string.slice!(0, segment_length)
      end
    end

    components
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
    add_element(party, "commInvNo", g.string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: false))
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
    add_element(party, "commInvNo", g.string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: false))
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

  def additional_tariff_number invoice_date, country_of_origin, hts
    tariff = hts.to_s.strip.gsub(".", "")
    return [] if tariff.blank?

    # If the user didn't upload an invoice date, use the current date in eastern time
    invoice_date = ActiveSupport::TimeZone["America/New_York"].now.to_date if invoice_date.nil?

    @special_tariffs ||= SpecialTariffCrossReference.find_special_tariff_hash "US", true, reference_date: invoice_date
    Array.wrap(@special_tariffs.tariffs_for country_of_origin, tariff)
  end
end; end; end; end;
