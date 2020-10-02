require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/nokogiri_xml_helper'
require 'open_chain/custom_handler/gt_nexus/generic_gtn_asn_parser_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Advance; class AdvancePrep7501ShipmentParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::GtNexus::GenericGtnAsnParserSupport
  include OpenChain::CustomHandler::NokogiriXmlHelper

  def self.parse_file io, _log, opts = {}
    self.new.parse(xml_document(io), User.integration, opts[:key])
    nil
  end

  def parse xml, user, file
    importer = find_importer(xml)
    inbound_file.company = importer
    parties = parse_parties(importer, xml)
    products_cache = parse_parts(importer, xml, user, file)
    orders_cache = parse_orders(importer, xml, products_cache, user, file)

    parse_shipment(importer, xml, parties, orders_cache, user, file)
  end

  def parse_shipment importer, xml, parties, orders_cache, user, file
    s = nil
    find_or_create_shipment(importer, xml) do |shipment|
      # The 7501 is a complete picture of the shipment as we handle it, so just destroy and re-add all the lines and containers
      shipment.containers.destroy_all
      shipment.shipment_lines.destroy_all

      shipment.ship_from = parties[:ship_from]
      shipment.consignee = parties[:consignee]
      shipment.ship_to = parties[:ship_to]
      # For whatever reason, we get whitespace (non-breaking spaces, other non-printing chars) at the end of the BOL from time to time, strip it
      # otherwise there is problems sending the data to Kewill
      shipment.house_bill_of_lading = first_text(xml, "/Prep7501Message/Prep7501/AggregationLevel[@Type='BL']", true).gsub(/[[:space:]]/, "")
      inbound_file.add_identifier :house_bill, shipment.house_bill_of_lading

      asn = first_xpath(xml, "/Prep7501Message/Prep7501/ASN")
      if !asn.nil?
        shipment.mode = et(asn, "Mode")
        shipment.voyage = et(asn, "Voyage")
        shipment.vessel = et(asn, "Vessel")
        shipment.country_origin = find_port_country(first_xpath(asn, "OriginCity"))
        # If there's no OriginCity, fall back to the PortOfLoading
        shipment.country_origin = find_port_country(first_xpath(asn, "PortOfLoading")) if shipment.country_origin.nil?
        shipment.country_export = find_port_country(first_xpath(asn, "PortOfLoading"))
        shipment.country_import = find_port_country(first_xpath(asn, "BLDestination"))
        # If there's no BLDestination, fall back to the PortOfDischarge
        shipment.country_import = find_port_country(first_xpath(asn, "PortOfDischarge")) if shipment.country_import.nil?

        if shipment.country_import.nil? && shipment.importer.system_code == "CQ"
          inbound_file.reject_and_raise "BLDestination CountryCode must be present for all CQ Prep7501 Documents."
        end

        shipment.lading_port = find_port(first_xpath(asn, "PortOfLoading"))
        shipment.unlading_port = find_port(first_xpath(asn, "PortOfDischarge"))
        shipment.final_dest_port = find_port(first_xpath(asn, "BLDestination"), lookup_type_order: [:unlocode, :schedule_k_code, :schedule_d_code])

        shipment.est_departure_date = parse_date et(asn, "EstDepartDate")
        shipment.est_arrival_port_date = parse_date et(asn, "EstDischargePortDate")
        shipment.departure_date = parse_reference_date asn, "Departed", datatype: :date
      end

      container_xmls = []
      # For whatever reason, the container data for a single container number can be split across multiple
      # ASN elements.  For that reason, just build the containers and then process all the line items
      # after doing that.  This also allows sorting the line items across the whole shipment rather than
      # just a single ASN.
      xpath(xml, "/Prep7501Message/Prep7501/ASN/Container") do |container_xml|
        parse_container(shipment, container_xml)
        container_xmls << container_xml
      end

      # Don't make lines if there were any errors...at this point any errors are going to have to do with missing Order / Product data..
      # So we can't make order lines...ergo, don't attempt to
      if !inbound_file.failed?
        # The data in the XML seems to come in an entirely random order.  It doesn't match the order of the
        # paper packing list or the commercial invoice (even the commercial invoice data inside this 7501
        # doesn't match the order of the commercial invoice - it's totally random).
        # The existing feed orders the data based on the LineItemNumber (.ie the PO line number), so we'll continue
        # doing that.
        sorted_line_items(container_xmls).each do |item_xml|
          parse_shipment_line(shipment, item_xml, orders_cache)
        end

        # If the shipment was fully processed, we can mark it to be sent to the entry system
        shipment.find_and_set_custom_value cdefs[:shp_entry_prepared_date], Time.zone.now
      end

      shipment.save!
      shipment.create_snapshot user, nil, file
      s = shipment
    end

    # Put this outside the find_or_create because it should not roll back the save..we want to actually
    # save as much of the shipment that got generated as possible.  In general, this is going to mean
    # that the shipment lines aren't saved.
    if inbound_file.failed?
      inbound_file.reject_and_raise "Failed to fully process file due to error. Once the errors are fixed, the file can be reprocessed."
    end

    s
  end

  def sorted_line_items container_xmls
    items = []
    container_xmls.each do |container_xml|
      line_items = xpath(container_xml, "LineItems")
      items.push(*line_items) if line_items.length > 0
    end

    items.sort do |a, b|
      v = et(a, "PONumber", true) <=> et(b, "PONumber", true)

      if v == 0
        v = et(a, "LineItemNumber", true).to_i <=> et(b, "LineItemNumber", true).to_i
      end

      v
    end
  end

  def parse_container shipment, xml
    container_number = et(xml, "ContainerNumber")
    container = shipment.containers.find { |c| container_number == c.container_number }
    if container.blank?
      container = shipment.containers.build container_number: container_number
    end
    container.container_size = et(xml, "ContainerType")
    container.fcl_lcl = et(xml, "ContainerLoad")
    container.seal_number = et(xml, "SealNumber")

    container
  end

  def parse_shipment_line shipment, line_xml, orders_cache
    line = shipment.shipment_lines.build
    container_number = et(line_xml.parent, "ContainerNumber")

    line.container = shipment.containers.find { |c| c.container_number == container_number }
    line.invoice_number = et(line_xml, "InvoiceNumber")
    line_number = et(line_xml, "LineItemNumber").to_i
    if line.invoice_number.blank?
      inbound_file.add_reject_message "Container # #{container_number} line # #{line_number} is missing an invoice number."
    end

    # The carton count on the XML is invalid...It's the piece count, not the actual # of cartons
    line.carton_qty = 0
    line.quantity = parse_decimal(et(line_xml, "Quantity"))
    line.gross_kgs = parse_weight(first_xpath(line_xml, "Weight"))
    line.cbms = parse_volume(first_xpath(line_xml, "Volume"))

    order_number = et(line_xml, "PONumber")
    order = orders_cache[order_number]
    if order
      if advan_importer? shipment.importer
        order_line = order.order_lines.find {|ol| ol.line_number == line_number }
        # This really should never happend at all since we're making orders / products in this parser
        inbound_file.reject_and_raise "Failed to find Order # '#{order_number}' / Line Number #{line_number}." unless order_line
      else
        product_code = et(line_xml, "ProductCode")
        order_line = find_cq_order_line_by_part_number(order, product_code)

        # This really should never happen at all since we're rejecting the file when it's looking up orders if it can't find the order line
        # based on the product code given in the 7501.
        inbound_file.reject_and_raise "Failed to find Order # '#{order_number}' / Product Code #{product_code}." unless order_line
      end

      line.product = order_line.product
      line.linked_order_line_id = order_line.id
    else
      # This really should never happend at all since we're making orders / products in this parser
      inbound_file.reject_and_raise "Failed to find Order #'#{order_number}'."
    end

    line
  end

  def find_or_create_shipment importer, xml
    # We don't actually get a master bill for these, so we'll use the house bill as the reference
    house_bill = et(xml, "/Prep7501Message/Prep7501/AggregationLevel[@Type='BL']")
    inbound_file.reject_and_raise "No Bill of Lading present." if house_bill.blank?

    last_exported_from_source = parse_datetime(et(xml, "/Prep7501Message/TransactionInfo/Created"))

    reference = "#{importer.system_code}-#{house_bill}"
    inbound_file.add_identifier :shipment_number, reference
    shipment = nil
    Lock.acquire(reference) do
      s = Shipment.where(importer_id: importer.id, reference: reference).first_or_create! last_exported_from_source: last_exported_from_source
      inbound_file.set_identifier_module_info(:shipment_number, Shipment, s.id) if s

      if process_shipment?(s, last_exported_from_source)
        shipment = s
      else
        inbound_file.add_warning_message "Shipment could not be updated. The Prep 7501 file's Created time of " +
                                         "'#{last_exported_from_source.in_time_zone("America/New_York")}' is " +
                                         "prior to the current Shipment's value of " +
                                         "'#{s.last_exported_from_source.in_time_zone("America/New_York")}'."
      end
    end

    if shipment
      Lock.db_lock(shipment) do
        return nil unless process_shipment?(shipment, last_exported_from_source)

        yield shipment
      end
    end

    shipment
  end

  def process_shipment? shipment, last_exported_from_source
    shipment.last_exported_from_source.nil? || shipment.last_exported_from_source <= last_exported_from_source
  end

  def parse_orders importer, xml, products_cache, user, file
    orders_cache = {}
    snapshots = Set.new
    asn_line_items(xml) do |line_xml|
      order, snapshot = find_or_create_order(importer, line_xml, xml, orders_cache, products_cache)
      snapshots << order if order && snapshot
    end

    snapshots.each do |order|
      Lock.db_lock(order) do
        order.save!
        order.create_snapshot user, nil, file
      end
    end

    orders_cache
  end

  def find_or_create_order importer, line_xml, xml, orders_cache, products_cache
    customer_order_number = et(line_xml, "PONumber")
    return nil if customer_order_number.blank?

    snapshot_order = false
    order = orders_cache[customer_order_number]

    if order.nil?
      order_number = "#{importer.system_code}-#{customer_order_number}"
      Lock.acquire("Order-#{order_number}") do
        order = Order.where(importer_id: importer.id, order_number: order_number).first_or_initialize customer_order_number: customer_order_number
        if !order.persisted?
          # All CQ orders should be present in the system, they are loaded via the Origin Report custom feature screen (what CQ calls the Tip Top report)
          # We should not create orders here...we can error if the order is not found
          if importer.system_code == 'CQ'
            inbound_file.add_identifier :po_number, customer_order_number
            inbound_file.add_reject_message "PO # #{customer_order_number} is missing."
            return nil
          else
            snapshot_order = true
            order.save!
          end
        end
        inbound_file.add_identifier :po_number, customer_order_number, object: order
      end
    end

    product_code = et(line_xml, "ProductCode", true)
    product = products_cache[product_code]
    Lock.db_lock(order) do
      line_number = et(line_xml, "LineItemNumber", true).to_i

      if advan_importer? importer
        # Line number is supposed to be a unique line number, not 100% sure it's unique to the order for ADVAN.
        line = order.order_lines.find {|l| l.line_number == line_number }

        # If we happen to hit a case where the line number is shared between shipments and has different products on it
        # then we have no option but to error here.
        inbound_file.reject_and_raise "A line number collision occurred for PO #{customer_order_number} / Line # #{line_number}." if line && line.product_id != product.id

        if line.nil?
          line = order.order_lines.build product_id: product.id, line_number: line_number
        end
      else
        # All CQ orders should already be in the system via the PO Origin Report Upload (they need to load this
        # so that we have the unit cost of the products).  This means that we'll just look for the first order line
        # that has the same product code...products pulled from the product_cache for CQ is actually just the part code, NOT an actual product.
        line = find_cq_order_line_by_part_number(order, product_code)

        if line.nil?
          inbound_file.add_reject_message "PO # #{customer_order_number} is missing part number #{product_code}."
          return nil
        end
      end

      # This data is pulled from the Invoice portion of the XML..
      invoice_line = first_xpath(xml, "/Prep7501Message/Prep7501/CommercialInvoice/Item[PurchaseOrderNumber='#{customer_order_number}' and " +
                                      "ItemNumber='#{product_code}' and UserRefNumber='#{line_number}']")
      if invoice_line.nil?
        inbound_file.add_reject_message "Unable to find Commerical Invoice Line for Order Number #{customer_order_number} / Item Number #{product_code} / Line #{line_number}"
        return nil
      end

      line.quantity = parse_decimal(et(invoice_line, "Quantity"))
      line.unit_of_measure = et(invoice_line, "QuantityUOM")

      if advan_importer? importer
        # For whatever reason, CQ invoices don't have pricing included on them.  The unit cost needs to come from
        # the CQ PO Origin Report (AdvancePoOriginReportParser).
        total_cost = first_xpath(invoice_line, "ItemTotalPrice")
        if total_cost
          val = parse_decimal(et(total_cost, ".", true))
          if line.quantity && val
            line.price_per_unit = val / line.quantity
          end

          line.currency = first_text(total_cost, "@Currency")
        end
      end

      coo = et(invoice_line, "PartyInfo[Type = 'Factory']/CountryCode")

      # Don't overwrite an existing country of origin if the prep 7501's might be blank
      line.country_of_origin = coo if coo.present?

      if !line.persisted? || line.changed?
        line.save!
        snapshot_order = true
      end
    end

    orders_cache[customer_order_number] = order
    [order, snapshot_order]
  end

  def parse_parts importer, xml, user, file
    products = {}
    asn_line_items(xml) do |line_item|
      find_or_create_product importer, line_item, products, user, file
    end

    products
  end

  def asn_line_items xml
    xpath(xml, "Prep7501Message/Prep7501/ASN/Container/LineItems") do |line_item|
      yield line_item
    end
  end

  def find_or_create_product importer, xml, cache, user, file
    product = nil
    part_number = et(xml, "ProductCode")
    return nil if part_number.blank?

    # For CQ, we're not actually going to create parts (they should already exist due to the Origin Report upload).  If they don't
    # the order linking part of this parser will fail anyway.  Just return the part number from the 7501, which we'll then use
    # to look up order lines.
    if cq_importer? importer
      product = part_number
    else
      unique_identifier = "#{importer.system_code}-#{part_number}"
      Lock.acquire("Product-#{unique_identifier}") do
        # The products SHOULD all exist already, and we don't want to update data on them if they do.
        product = Product.where(unique_identifier: unique_identifier, importer_id: importer.id).first_or_initialize

        if !product.persisted?
          product.name = et(xml, "ProductName")
          product.find_and_set_custom_value cdefs[:prod_part_number], part_number

          product.save!
          product.create_snapshot user, nil, file
        end
      end
    end

    cache[part_number] = product

    product
  end

  def parse_parties importer, xml
    parties = {}
    # Need Supplier (We'll use Ship From Address), Final Dest (We'll use Ship To, linked to Importer)
    consignee = xpath(xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'Consignee']").first
    parties[:consignee] = find_or_create_company_address(importer, consignee, {consignee: true}) if consignee

    ship_from = xpath(xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'Supplier']").first
    parties[:ship_from] = find_or_create_address(importer, ship_from) if ship_from

    ship_to = xpath(xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'ShipmentFinalDest']").first
    parties[:ship_to] = find_or_create_address(importer, ship_to) if ship_to

    parties
  end

  def find_or_create_address importer, address_xml
    address = parse_address_data(importer, address_xml)

    found = nil
    hash = Address.make_hash_key address
    Lock.acquire("Address-#{hash}") do
      found = Address.where(company_id: importer.id, address_hash: hash).first

      if found.nil?
        address.save!
        found = address
      end
    end

    found
  end

  def parse_address_data importer, address_xml
    # Since we don't have reliable system codes for the addresses in this feed, we need to rely on the address hashing functionality
    # to try and tie address in the xml w/ existing addresses.
    a = Address.new
    a.company = importer
    a.address_type = et(address_xml, "Type")
    a.name = et(address_xml, "Name")
    lines = xpath(address_xml, "Address/AddressLine").map(&:text)
    a.line_1 = lines[0]
    a.line_2 = lines[1]
    a.line_3 = lines[2]
    a.city = et(address_xml, "City/CityName")
    a.state = et(address_xml, "City/State")
    country_code = et(address_xml, "City/CountryCode")
    a.country = Country.where(iso_code: country_code).first if !country_code.nil?
    a.postal_code = et(address_xml, "PostalCode")

    a
  end

  def find_or_create_company_address importer, address_xml, company_type_hash
    address = parse_address_data(nil, address_xml)

    # Use the address hash as the system code, its the only piece of identifying information we get from the 7501 XML, and the companies we create from this
    # or pretty much solely used to convey address information to the outbound files we generate for them.
    hash = Address.make_hash_key address
    company = nil
    Lock.acquire("Address-#{hash}") do
      company = Company.where(system_code: "#{importer.system_code}-#{hash}").first_or_initialize
      if !company.persisted?
        company.name = address.name
        company.assign_attributes company_type_hash
        company.addresses << address
        company.save!

        importer.linked_companies << company
      end
    end

    company
  end

  def find_importer xml
    # We determine the importer account by first determining if we have an Advanced or CQ file or not, by looking at the Consignee.
    # If the importer is Carquest, the existing ECS system the routes it to Canada or US based on the CountryCode associated with the BLDestination.
    # We're storing the port code associated with that account as the final destination.  Our comparator that will trigger the CI Load / Fenix 810 will
    # use the UN/Locodes country portion to determine if a Canada or US document should be generated.
    consignee = xpath(xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'Consignee']").first
    inbound_file.reject_and_raise "Invalid XML.  No Consignee could be found." unless consignee

    name = et(consignee, "Name")
    if (name =~ /Carquest/i) || (name =~ /CQ/i)
      importer = Company.where(system_code: "CQ").first
    elsif name =~ /Advance/i
      importer = Company.where(system_code: "ADVAN").first
    end

    inbound_file.reject_and_raise "Failed to find Importer account for Consignee name '#{name}'." unless importer

    importer
  end

  def cq_importer? company
    company.system_code == "CQ"
  end

  def advan_importer? company
    company.system_code == "ADVAN"
  end

  def find_cq_order_line_by_part_number order, part_number
    # CQ has not been able to consistently send us part numbers from the origin report that match correctly to the prep 7501.  The
    # numbers on the origin report tend to be missing punctuation that's on the prep 7501.  So, we're going to strip punctuation
    # and see which order line's product matches the part number (which should already have stripped punctuation)
    pn = normalize_part_number(part_number).upcase
    order.order_lines.find do |order_line|
      normalize_part_number(order_line.product&.custom_value(cdefs[:prod_part_number])).upcase == pn
    end
  end

  def normalize_part_number part_number
    part_number.to_s.gsub(/[^[[:alnum:]]]/, "")
  end

  def cdefs
    @cdefs = self.class.prep_custom_definitions([:prod_part_number, :shp_entry_prepared_date])
  end

end; end; end; end
