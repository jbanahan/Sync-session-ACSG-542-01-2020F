require 'open_chain/fixed_position_generator'
require 'open_chain/custom_handler/vandegrift/kewill_web_services_support'

module OpenChain; module CustomHandler; module Vandegrift; module KewillShipmentXmlSupport
  include OpenChain::CustomHandler::Vandegrift::KewillWebServicesSupport
  extend ActiveSupport::Concern

  CI_LOAD_DATE_CODES ||= {
    est_arrival_date: "dateEstArrival",
    arrival_date: "dateArrival",
    elected_entry_date: "dateEntry",
    export_date: "1",
    import_date: "7",
    edi_received_date: "dateReceived"
  }

  # UOM
  #  CTNS = Cartons
  #  M3 = Cubic Meters
  #  KG = Kilogram

  # The included here is done so that every generator instance that includes this module can have the structs below
  # namespaced to their own class
  included do
    CiLoadEntry ||= Struct.new(
      :file_number, :customer, :invoices, :containers, :bills_of_lading, :dates, :edi_identifier, :customer_reference, :vessel, :voyage, :carrier,
      :customs_ship_mode, :lading_port, :unlading_port, :entry_port, :pieces, :pieces_uom, :goods_description, :weight_kg, :consignee_code,
      :ultimate_consignee_code, :country_of_origin, :country_of_export, :location_of_goods, :destination_state, :bond_type, :entry_filer_code,
      :entry_type, :entry_number, :total_value_us, :firms_code, :charges, :recon_value_flag
    )
    # You don't have to use scac in general when sending an EDI Identifier, just put the full master bill in the
    # master_bill field.  The internals of this class will end up splitting the master bill into the scac / numeric components
    # to send to Customs Management
    CiLoadEdiIdentifier ||= Struct.new(:master_bill, :house_bill, :sub_bill, :sub_sub_bill, :scac, :container_numbers)
    # code is the symbol matching to the key above in the CI_LOAD_DATE_CODES constant
    # In other words, to send an export date use a code of "1"...to send an Arrival Date, use a code of 'arrival_date'
    CiLoadEntryDate ||= Struct.new(:code, :date)
    CiLoadBillsOfLading ||= Struct.new(:master_bill, :house_bill, :sub_bill, :sub_sub_bill, :pieces, :pieces_uom)
    CiLoadContainer ||= Struct.new(:container_number, :seal_number, :size, :description, :pieces, :pieces_uom, :weight_kg, :container_type) # rubocop:disable Lint/StructNewOverride
    CiLoadInvoice ||= Struct.new(
      :invoice_number, :invoice_date, :invoice_lines, :non_dutiable_amount, :add_to_make_amount, :uom, :currency, :exchange_rate, :file_number,
      :invoice_total, :charges, :customer_reference, :gross_weight_kg, :net_weight, :net_weight_uom, :quantity
    )
    CiLoadInvoiceLine ||= Struct.new(
      :tariff_lines, :part_number, :country_of_origin, :country_of_export, :gross_weight, :pieces, :pieces_uom, :hts, :foreign_value,
      :quantity_1, :uom_1, :quantity_2, :uom_2, :po_number, :first_sale, :department, :spi, :non_dutiable_amount, :cotton_fee_flag, :mid, :cartons,
      :add_to_make_amount, :unit_price, :unit_price_uom, :buyer_customer_number, :seller_mid, :spi2, :line_number, :charges, :related_parties,
      :description, :container_number, :ftz_quantity, :ftz_zone_status, :ftz_priv_status_date, :ftz_expired_hts_number, :category_number, :parties,
      :exported_date, :visa_number, :visa_date, :lading_port, :textile_category_code, :ruling_type, :ruling_number, :quantity_3, :uom_3, :net_weight, :net_weight_uom
    )
    CiLoadInvoiceTariff ||= Struct.new(:hts, :gross_weight, :spi, :spi2, :foreign_value, :quantity_1, :uom_1, :quantity_2, :uom_2, :quantity_3, :uom_3)
    # Qualifier should be one of MF (Manufacturer) or BY (Buyer)
    CiLoadParty ||= Struct.new(:qualifier, :name, :address_1, :address_2, :address_3, :city, :country_subentity, :zip, :country, :customer_number, :mid) # rubocop:disable Lint/StructNewOverride
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
    add_element(parent, "fileNo", g.string(entry.file_number, 15, pad_string: false, exception_on_truncate: true)) unless entry.file_number.blank?
    add_element(parent, "custNo", g.string(entry.customer, 10, pad_string: false, exception_on_truncate: true))
    add_element(parent, "entryType", g.string(entry.entry_type, 2, pad_string: false)) unless entry.entry_type.blank?
    add_element(parent, "entryFilerCode", g.string(entry.entry_filer_code, 3, pad_string: false)) unless entry.entry_filer_code.blank?
    add_element(parent, "entryNo", g.string(entry.entry_number, 9, pad_string: false)) unless entry.entry_number.blank?
    add_element(parent, "valueUsAmt", g.number(entry.total_value_us, 13, decimal_places: 2, pad_string: false)) unless entry.total_value_us.blank?

    add_element(parent, "custRef", g.string(entry.customer_reference, 35, pad_string: false)) unless entry.customer_reference.blank?
    add_element(parent, "vesselAirlineName", g.string(entry.vessel, 20, pad_string: false)) unless entry.vessel.blank?
    add_element(parent, "voyageFlightNo", g.string(entry.voyage, 10, pad_string: false)) unless entry.voyage.blank?
    # This is just some weirdness so that Kewill doesn't generate a secondary scac-less master bill record
    add_element(parent, "scac", g.string(edi_identifier.scac, 4, pad_string:false)) unless edi_identifier.scac.blank?
    add_element(parent, "carrier", g.string(entry.carrier, 4, pad_string: false)) unless entry.carrier.blank?
    add_element(parent, "mot", g.number(entry.customs_ship_mode, 2, decimal_places: 0, strip_decimals: true, pad_string: false)) unless entry.customs_ship_mode.blank?
    add_element(parent, "portLading", g.string(entry.lading_port, 5, pad_string: false)) unless entry.lading_port.blank?
    add_element(parent, "distPort", g.string(entry.unlading_port, 4, pad_string: false)) unless entry.unlading_port.blank?
    add_element(parent, "distPortEntry", g.string(entry.entry_port, 4, pad_string: false)) unless entry.entry_port.blank?

    add_element(parent, "pieceCount", g.number(entry.pieces, 12, decimal_places: 0, strip_decimals: true, pad_string: false)) if nonzero?(entry.pieces)

    # Operations has asked that we default to CTNS even if no piece / package count is present...because that is the UOM used "99%" of the time.
    pieces_uom = entry.pieces_uom.presence || "CTNS"
    add_element(parent, "uom", g.string(pieces_uom, 6, pad_string: false))

    add_element(parent, "descOfGoods", g.string(entry.goods_description, 70, pad_string: false)) unless entry.goods_description.blank?

    if entry.weight_kg && entry.weight_kg > 0
      add_element(parent, "weightGross", g.number(entry.weight_kg, 12, decimal_places: 0, pad_string: false))
      add_element(parent, "uomWeight", "KG")
    end

    add_element(parent, "consignee", g.string(entry.consignee_code, 10, pad_string: false)) unless entry.consignee_code.blank?
    add_element(parent, "ultimateConsignee", g.string(entry.ultimate_consignee_code, 10, pad_string: false)) unless entry.ultimate_consignee_code.blank?
    add_element(parent, "countryOrigin", g.string(entry.country_of_origin, 2, pad_string: false, exception_on_truncate: true)) unless entry.country_of_origin.blank?
    add_element(parent, "countryExport", g.string(entry.country_of_export, 2, pad_string: false, exception_on_truncate: true)) unless entry.country_of_export.blank?
    add_element(parent, "bondType", g.string(entry.bond_type, 1, pad_string: false)) unless entry.bond_type.blank?
    add_element(parent, "destinationState", g.string(entry.destination_state, 2, pad_string: false)) unless entry.destination_state.blank?
    add_element(parent, "firmsCode", g.string(entry.firms_code, 4, pad_string: false)) unless entry.firms_code.blank?
    add_element(parent, "reconValue", "Y") if entry.recon_value_flag
    add_element(parent, "chargesAmt", g.number(entry.charges, 13, decimal_places: 2, pad_string: false, max_value: BigDecimal("99999999999.99"), exclude_decimal_from_length_validation: true)) if entry.charges

    generate_shipment_header_aux(parent, entry, edi_identifier)
    generate_bills(parent, entry, edi_identifier)
    generate_entry_dates(parent, entry, edi_identifier)
    generate_containers(parent, entry, edi_identifier)

    parent
  end

  def generate_shipment_header_aux(parent, entry, edi_identifier)
    # For the moment, location of goods is the only field in the Aux element we're sending so just
    # skip it unless that field is present
    if entry.location_of_goods.present?
      aux = add_element(parent, "EdiShipmentHeaderAux")
      generate_identifier_data(aux, edi_identifier)
      add_element(aux, "locationOfGoods", g.string(entry.location_of_goods, 35, pad_string: false))
    end
  end

  def generate_entry_dates parent, entry, edi_identifier
    list = nil

    # Unless the date is already present, we're going to add the current date as the dateReceived.  Which shows up as EDI Received Date
    # in the Load EDI search screen in CMUS.
    received_date = Array.wrap(entry.dates).find {|d| d.code == :edi_received_date }
    if received_date.nil?
      entry.dates ||= []
      entry.dates << CiLoadEntryDate.new(:edi_received_date, ActiveSupport::TimeZone["America/New_York"].now.to_date)
    end

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

  def generate_bills(parent, entry, edi_identifier)
    if Array.wrap(entry.bills_of_lading).length > 0
      id_list = add_element(parent, "EdiShipmentIdList")

      Array.wrap(entry.bills_of_lading).each_with_index do |bill_of_lading, bol_index|
        shipment_id = generate_shipment_id(id_list, bill_of_lading, edi_identifier, (bol_index + 1))
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

      # Use the first bill of lading and generate an identifier from it.  All containers will be included.
      # They are not mandatory here, however.
      identifier = generate_entry_identifier_from_bol_and_containers bills.first, entry.containers
    else
      raise MissingCiLoadDataError, "At least one Edi Identifier value must be present." if identifier.master_bill.blank? && identifier.house_bill.blank? && identifier.sub_bill.blank? && identifier.sub_sub_bill.blank?
    end

    identifier
  end

  def generate_entry_identifier_from_bol_and_containers bill_of_lading, containers
    identifier = CiLoadEdiIdentifier.new
    if !bill_of_lading.master_bill.blank?
      scac, bol = chop_bill(bill_of_lading.master_bill.to_s.strip)
      identifier.scac = scac
      identifier.master_bill = bol
    end

    identifier.house_bill = chop_bill(bill_of_lading.house_bill.to_s.strip)[1] if !bill_of_lading.house_bill.blank?
    identifier.sub_bill = chop_bill(bill_of_lading.sub_bill.to_s.strip)[1] if !bill_of_lading.sub_bill.blank?
    identifier.sub_sub_bill = chop_bill(bill_of_lading.sub_sub_bill.to_s.strip)[1] if !bill_of_lading.sub_sub_bill.blank?

    # This will ultimately force an association between the containers and the bill number in CMUS.
    if containers.length > 0
      identifier.container_numbers = containers.map(&:container_number).to_a
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
    add_element(c, "noContainer", g.string(container.container_number, 15, pad_string: false)) unless container.container_number.blank?
    add_element(c, "sealNo", g.string(container.seal_number, 15, pad_string: false)) unless container.seal_number.blank?
    add_element(c, "custNo", g.string(entry.customer, 10, pad_string: false))
    add_element(c, "contSize", g.string(container.size, 7, pad_string: false)) unless container.size.blank?
    add_element(c, "descContent1", g.string(container.description, 40, pad_string: false)) unless container.description.blank?
    add_element(c, "containerType", g.string(container.container_type, 5, pad_string: false)) unless container.container_type.blank?

    # Operations has asked that we default to CTNS even if no piece / package count is present...because that is the UOM used "99%" of the time.
    pieces_uom = container.pieces_uom.presence || "CTNS"
    add_element(c, "uom", g.string(pieces_uom, 6, pad_string: false))

    # Pieces and UOM must both be present
    if container.pieces.to_i > 0
      add_element(c, "pieces", container.pieces.to_i)
    end

    if container.weight_kg && container.weight_kg.to_d > 0
      add_element(c, "weight", g.number(container.weight_kg, 12, decimal_places: 0, pad_string: false))
      add_element(c, "uomWeight", "KG")
    end

  end

  def generate_shipment_id parent, bol, edi_identifier, sequence
    id = add_element(parent, "EdiShipmentId")
    add_element(id, "seqNo", sequence)
    generate_identifier_data(id, edi_identifier)

    # Because Kewill, in their not-so-infinite wisdom, used houseBill/MasterBill as the unique identifier to tie
    # all this data together in the EDI system of the Customs Management system...if you actually want to use
    # multiple bills of lading...you need to use fields called MASTER_BILL_ADDL and HOUSE_BILL_ADDL
    # we're going to assume that if the sequence is > 1 then we're dealing with additional bills

    scac, bill = chop_bill(bol.master_bill)
    add_element(id, "scac", g.string(scac, 4, pad_string: false)) unless scac.blank?
    add_element(id, "masterBillAddl", g.string(bill, 12, pad_string: false)) unless bill.blank?
    house_scac, bill = chop_bill(bol.house_bill)
    add_element(id, "scacHouse", g.string(house_scac, 4, pad_string: false)) unless scac.blank?
    add_element(id, "houseBillAddl", g.string(bill, 12, pad_string: false)) unless bill.blank?

    *, sub_bill = chop_bill(bol.sub_bill)
    add_element(id, "subBillAddl", g.string(sub_bill, 12, pad_string: false)) unless sub_bill.blank?
    *, sub_sub_bill = chop_bill(bol.sub_sub_bill)
    add_element(id, "subSubBillAddl", g.string(sub_sub_bill, 12, pad_string: false)) unless sub_sub_bill.blank?

    add_element(id, "qty", g.number(bol.pieces, 12, decimal_places: 0, pad_string: false)) if nonzero?(bol.pieces)
    add_element(id, "uom", g.string(bol.pieces_uom, 6, pad_string: false)) unless bol.pieces_uom.blank?

    # Kind of a hack to force an association between the containers and the bill number in CMUS,
    # necessary for reporting purposes.
    #
    # The seqNo and scac value in in EdiShipmentIdContainers are, intentionally, the same value as the
    # seqNo / scac in EdiShipmentId.  The only value that should differ between each EdiShipmentIdContainers
    # should be the noContainer, which is the container number.
    if edi_identifier.container_numbers&.length.to_i > 0
      elem_edi_shipment_id_containers_list = add_element(id, "EdiShipmentIdContainersList")
      edi_identifier.container_numbers.each do |cont|
        elem_edi_shipment_id_containers = add_element(elem_edi_shipment_id_containers_list, "EdiShipmentIdContainers")
        add_element(elem_edi_shipment_id_containers, "seqNo", sequence)
        generate_identifier_data(elem_edi_shipment_id_containers, edi_identifier)
        add_element(elem_edi_shipment_id_containers, "scac", g.string(scac, 4, pad_string: false)) unless scac.blank?
        add_element(elem_edi_shipment_id_containers, "noContainer", g.string(cont, 15, pad_string: false))
      end
    end

    id
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

    if nonzero?(invoice.quantity)
      quantity = invoice.quantity
    else
      # Sum the carton totals from the lines (for some reason qty on invoice has no decimal places)
      quantity = lines.inject(BigDecimal("0")) {|sum, line| sum += (nonzero?(line.cartons) ? line.cartons : 0)}
    end

    add_element(parent, "qty", g.number(quantity, 12, decimal_places: 0, strip_decimals: true, pad_string: false))
    # Always set the uom to be CTNS if it's blank
    add_element(parent, "uom", g.string((invoice.uom.to_s.blank? ? "CTNS" : invoice.uom), 6, pad_string: false))
    add_element(parent, "chargesAmt", g.number(invoice.charges, 13, decimal_places: 2, pad_string: false, max_value: BigDecimal("99999999999.99"), exclude_decimal_from_length_validation: true)) if invoice.charges

    if nonzero?(invoice.net_weight)
      add_element(parent, "netWeightAmt", g.number(invoice.net_weight, 15, decimal_places: 5, pad_string: false, max_value: BigDecimal("9999999.99999")))
      uom = invoice.net_weight_uom.presence || "KG"
      add_element(parent, "netWtUom", g.string(uom, 6, pad_string: false))
    end

    add_element(parent, "custRef", g.string(invoice.customer_reference, 35, pad_string: false, exception_on_truncate: false)) unless invoice.customer_reference.blank?
    add_element(parent, "weightGross", g.number(invoice.gross_weight_kg, 12, decimal_places: 0, pad_string: false)) if nonzero?(invoice.gross_weight_kg)

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

    mid = line.mid
    if line.mid.blank?
      # See if there's an MF party with an MID, if so, pull it from there
      mid = mid_from_manufacturer_party(line)
    end

    add_element(parent, "manufacturerId2", g.string(mid, 15, pad_string: false, exception_on_truncate: true)) unless mid.blank?
    add_element(parent, "cartons", g.number(line.cartons, 12, decimal_places: 0, strip_decimals: true, pad_string: false)) if nonzero?(line.cartons)

    seller_mid = get_seller_mid(line) unless line.seller_mid.blank?
    buyer_address = get_buyer(line) unless line.buyer_customer_number.blank?

    if seller_mid || buyer_address || Array.wrap(line.parties).length > 0
      parties = add_element(parent, "EdiInvoicePartyList")
      add_seller_mid(parties, entry, invoice, invoice_line_number, seller_mid) if seller_mid
      add_buyer(parties, entry, invoice, invoice_line_number, buyer_address) if buyer_address

      Array.wrap(line.parties).each do |party|
        # If we had an MID already included, then skip sending the MF party..we don't need it
        next if mid.present? && party.qualifier.to_s.upcase == "MF"

        add_invoice_line_party(parties, entry, invoice, invoice_line_number, party)
      end

      # Don't leave a blank parties element in the line
      parent.delete_element(parties) if parties.children.length == 0
    end

    add_element(parent, "detailLineNo", line.line_number.to_i) unless line.line_number.blank?
    add_element(parent, "chargesAmt", g.number(line.charges, 11, decimal_places: 2, pad_string: false)) if nonzero?(line.charges)
    add_element(parent, "relatedParties", g.string((true?(line.related_parties) ? "Y" : "N"), 1, pad_string: false, exception_on_truncate: false)) unless line.related_parties.nil?
    add_element(parent, "ftzQuantity", g.number(line.ftz_quantity, 10, pad_string: false, decimal_places: 0)) if nonzero?(line.ftz_quantity)
    add_element(parent, "ftzZoneStatus", g.string(line.ftz_zone_status, 1, pad_string: false, exception_on_truncate: true)) unless line.ftz_zone_status.blank?
    add_element(parent, "ftzPrivStatusDate", g.date(line.ftz_priv_status_date)) unless line.ftz_priv_status_date.blank?
    add_element(parent, "prevExpiredFtzTariffNo", g.string(line.ftz_expired_hts_number, 10, pad_string: false)) unless line.ftz_expired_hts_number.blank?

    add_element(parent, "descr", g.string(line.description, 40, pad_string: false)) unless line.description.blank?
    add_element(parent, "noContainer", g.string(line.container_number, 15, pad_string: false)) unless line.container_number.blank?
    add_element(parent, "categoryNo", g.string(line.category_number, 3, pad_string: false)) unless line.category_number.blank?
    add_element(parent, "dateExport", g.date(line.exported_date)) unless line.exported_date.nil?
    add_element(parent, "visaDate", g.date(line.visa_date)) unless line.visa_date.nil?
    add_element(parent, "visaNo", g.string(line.visa_number, 2, pad_string: false)) unless line.visa_number.blank?
    add_element(parent, "portLading", g.string(line.lading_port, 5, pad_string: false)) unless line.lading_port.blank?
    add_element(parent, "categoryNo", g.number(line.textile_category_code, 3, decimal_places: 0, pad_string: false)) unless line.textile_category_code.blank?
    add_element(parent, "rulingType", g.string(line.ruling_type, 1, pad_string: false)) unless line.ruling_type.blank?
    add_element(parent, "rulingNo", g.string(line.ruling_number, 6, pad_string: false)) unless line.ruling_number.blank?

    if nonzero?(line.net_weight)
      add_element(parent, "netWeightAmt", g.number(line.net_weight, 15, decimal_places: 5, pad_string: false, max_value: BigDecimal("9999999.99999")))
      uom = line.net_weight_uom.presence || "KG"
      add_element(parent, "netWtUom", g.string(uom, 6, pad_string: false))
    end

    tariff_lines = Array.wrap(line.tariff_lines)
    if add_special_tariffs?(entry, invoice, line)
      tariff_lines = process_special_tariffs(invoice, line, tariff_lines)
    end

    if tariff_lines.blank?
      add_tariff_fields(parent, line)
    else
      # If none of the tariff lines have a foreign value and the line does, then we'll just put it at the line level.
      # CM is able then to carry it down to the entered value for the tariff
      if tariff_lines_missing_value?(tariff_lines) && nonzero?(line.foreign_value)
        add_value_foreign(parent, line)
      end

      tariff_counter = 0
      tariff_class_element = add_element(parent, "EdiInvoiceTariffClassList")
      sort_tariff_lines(tariff_lines).each do |tariff|
        tariff_class = add_element(tariff_class_element, "EdiInvoiceTariffClass")
        add_invoice_tariff_line(tariff_class, entry, invoice, invoice_line_number, tariff, (tariff_counter += 1))
      end
    end

    nil
  end

  def tariff_lines_missing_value? tariffs
    !tariffs.any? {|t| nonzero?(t.foreign_value) }
  end

  def mid_from_manufacturer_party line
    manufacturer = Array.wrap(line.parties).find { |p| p.qualifier.to_s.upcase == "MF" }
    manufacturer&.mid.presence || nil
  end

  def sort_tariff_lines tariff_lines
    # Make sure any 9903 numbers appear first, then 9902 numbers and then just retain the original order of other
    # tariff lines
    sorted_lines = []

    dup_tariff_lines = tariff_lines.dup

    # The order the tariff numbers appear here are the priority order they'll end up in the actual output sorted
    # in front of the "primary tariffs"
    ["9903", "9902"].each do |priority_code|
      dup_tariff_lines.each_with_index do |t, index|
        next if t.nil?

        if t.hts.to_s.starts_with?(priority_code)
          sorted_lines << t
          dup_tariff_lines[index] = nil
        end
      end
    end
    sorted_lines.push *dup_tariff_lines.select {|t| !t.nil? }

    sorted_lines
  end

  def process_special_tariffs invoice, line, tariff_lines
    # In Kewill's EDI system you can send simple tariff data along w/ the commercial invoice line without having to send
    # child tariff line records.  However, if you do want to send multiple lines...then you need to send the child records.
    # We'll handle both ways...at least partially due to the handling of the special tariff cross references that allow for
    # adding special tariffs on the fly.
    if tariff_lines.length > 0
      # don't add special tariffs for tariff numbers that are already present in the tariff list
      existing_tariffs = Set.new(tariff_lines.map &:hts)

      special_tariff_line = nil
      special_tariff_lines = []
      tariff_lines.each do |tariff|
        special_tariffs = additional_tariff_number(invoice.invoice_date, line.country_of_origin, tariff.hts)
        special_tariffs.each_with_index do |special_tariff, idx|
          next if existing_tariffs.include?(special_tariff.special_hts_number)

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

    tariff_lines
  end

  # This method provides a way for including classes to disable the automatic addition of the supplemental tariffs
  def add_special_tariffs? entry, invoice, line
    true
  end

  def add_invoice_key_fields parent, entry, invoice, suppress_mid: false
    add_file_number(parent, entry, invoice) unless suppress_mid
    add_element(parent, "commInvNo", g.string(invoice.invoice_number, 22, pad_string: false, exception_on_truncate: false))
    add_element(parent, "dateInvoice", g.date(invoice.invoice_date)) unless invoice.invoice_date.nil?
  end

  def add_invoice_line_key_fields parent, entry, invoice, invoice_line_number, suppress_mid: false
    add_invoice_key_fields(parent, entry, invoice, suppress_mid: suppress_mid)
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
    add_value_foreign(parent, line)
    add_element(parent, "spiPrimary", g.string(line.spi, 2, pad_string: false)) unless line.spi.blank?
    add_element(parent, "spiSecondary", g.string(line.spi2, 2, pad_string: false)) unless line.spi2.blank?
    add_element(parent, "qty1Class", g.number(line.quantity_1, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.quantity_1)
    add_element(parent, "uom1Class", g.string(line.uom_1, 3, pad_string: false)) unless line.uom_1.blank?
    add_element(parent, "qty2Class", g.number(line.quantity_2, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.quantity_2)
    add_element(parent, "uom2Class", g.string(line.uom_2, 3, pad_string: false)) unless line.uom_2.blank?
    add_element(parent, "qty3Class", g.number(line.quantity_3, 12, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.quantity_3)
    add_element(parent, "uom3Class", g.string(line.uom_3, 3, pad_string: false)) unless line.uom_3.blank?
    nil
  end

  def add_value_foreign parent, line
    add_element(parent, "valueForeign", g.number(line.foreign_value, 13, decimal_places: 2, strip_decimals: true, pad_string: false)) if nonzero?(line.foreign_value)
  end

  def add_invoice_line_party parent, entry, invoice, invoice_line_number, party
    el = add_element(parent, "EdiInvoiceParty")
    add_invoice_line_key_fields(el, entry, invoice, invoice_line_number)
    add_element(el, "partiesQualifier", g.string(party.qualifier, 2, pad_string: false, exception_on_truncate: true))
    add_element(el, "custNo", g.string(party.customer_number, 10, pad_string: false, exception_on_truncate: true)) unless party.customer_number.blank?
    add_element(el, "name", g.string(party.name, 104, pad_string: false)) unless party.name.blank?
    add_element(el, "address1", g.string(party.address_1, 95, pad_string: false)) unless party.address_1.blank?
    add_element(el, "address2", g.string(party.address_2, 104, pad_string: false)) unless party.address_2.blank?
    add_element(el, "address3", g.string(party.address_3, 35, pad_string: false)) unless party.address_3.blank?
    add_element(el, "city", g.string(party.city, 93, pad_string: false)) unless party.city.blank?
    add_element(el, "countrySubentity", g.string(party.country_subentity, 9, pad_string: false)) unless party.country_subentity.blank?
    add_element(el, "country", g.string(party.country, 2, pad_string: false)) unless party.country.blank?
    add_element(el, "zip", g.string(party.zip, 9, pad_string: false)) unless party.zip.blank?
    add_element(el, "partyMidCd", g.string(party.mid, 15, pad_string: false, exception_on_truncate: true)) unless party.mid.blank?
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

  def add_seller_mid parent, entry, invoice, invoice_line_number, mid
    party = add_element(parent, "EdiInvoiceParty")
    add_invoice_line_key_fields(party, entry, invoice, invoice_line_number)
    add_element(party, "partiesQualifier", "SE")
    add_element(party, "address1", g.string(mid.address_1, 95, pad_string: false, exception_on_truncate: true)) unless mid.address_1.blank?
    add_element(party, "address2", g.string(mid.address_2, 104, pad_string: false, exception_on_truncate: true)) unless mid.address_2.blank?
    add_element(party, "city", g.string(mid.city, 93, pad_string: false, exception_on_truncate: true)) unless mid.city.blank?
    add_element(party, "country", g.string(mid.country, 2, pad_string: false, exception_on_truncate: true)) unless mid.country.blank?
    add_element(party, "name", g.string(mid.name, 104, pad_string: false, exception_on_truncate: true)) unless mid.name.blank?
    add_element(party, "zip", g.string(mid.postal_code, 9, pad_string: false, exception_on_truncate: true)) unless mid.postal_code.blank?
    add_element(party, "partyMidCd", g.string(mid.mid, 15, pad_string: false, exception_on_truncate: true)) unless mid.mid.blank?
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

      h[k] = Address.joins(:company).where(companies: {id: Company.with_customs_management_number(cust_no)}).where(system_code: address_no).first
    end

    address = @addresses[[cust_no, address_no]]

    raise MissingCiLoadDataError, "No Customer Address # '#{address_no}' found for '#{cust_no}'." unless address

    address
  end

  def add_buyer parent, entry, invoice, invoice_line_number, buyer
    party = add_element(parent, "EdiInvoiceParty")
    add_invoice_line_key_fields(party, entry, invoice, invoice_line_number)
    add_element(party, "partiesQualifier", "BY")
    add_element(party, "address1", g.string(buyer.line_1, 95, pad_string: false, exception_on_truncate: true)) unless buyer.line_1.blank?
    add_element(party, "address2", g.string(buyer.line_2, 104, pad_string: false, exception_on_truncate: true)) unless buyer.line_2.blank?
    add_element(party, "city", g.string(buyer.city, 93, pad_string: false, exception_on_truncate: true)) unless buyer.city.blank?
    add_element(party, "country", g.string(buyer.country.iso_code, 2, pad_string: false, exception_on_truncate: true)) unless buyer.country.try(:iso_code).blank?
    add_element(party, "countrySubentity", g.string(buyer.state, 9, pad_string: false, exception_on_truncate: true)) unless buyer.state.blank?
    add_element(party, "custNo", g.string(buyer.company.kewill_customer_number, 10, pad_string: false, exception_on_truncate: true)) unless buyer.company.try(:kewill_customer_number).blank?
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
