require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Advance; class AdvancePrep7501ShipmentParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.parse_file io, log, opts = {}
    self.new.parse(REXML::Document.new(io), User.integration, opts[:key])
    nil
  end

  def parse xml, user, file
    importer = find_importer(xml)
    inbound_file.company = importer
    parties = parse_parties(importer, xml)
    products_cache = parse_parts(importer, xml, user, file)
    orders_cache = parse_orders(importer, xml, parties, products_cache, user, file)

    parse_shipment(importer, xml, parties, orders_cache, products_cache, user, file)
  end

  def parse_shipment importer, xml, parties, orders_cache, products_cache, user, file
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
      shipment.house_bill_of_lading = xml.text("/Prep7501Message/Prep7501/AggregationLevel[@Type='BL']").to_s.gsub(/[[:space:]]/, "")
      inbound_file.add_identifier :house_bill, shipment.house_bill_of_lading

      asn = REXML::XPath.first xml, "/Prep7501Message/Prep7501/ASN"
      if !asn.nil?
        shipment.mode = asn.text "Mode"
        shipment.voyage = asn.text "Voyage"
        shipment.vessel = asn.text "Vessel"
        shipment.country_origin = find_country(REXML::XPath.first asn, "OriginCity")
        shipment.country_export = find_country(REXML::XPath.first asn, "PortOfLoading")
        shipment.country_import = find_country(REXML::XPath.first asn, "BLDestination")

        inbound_file.reject_and_raise "BLDestination CountryCode must be present for all CQ Prep7501 Documents." if shipment.country_import.nil? && shipment.importer.system_code == "CQ"

        shipment.lading_port = find_port(REXML::XPath.first asn, "PortOfLoading")
        shipment.unlading_port = find_port(REXML::XPath.first asn, "PortOfDischarge")
        shipment.final_dest_port = find_port(REXML::XPath.first(asn, "BLDestination"), lookup_type_order: [:unlocode, :schedule_k_code, :schedule_d_code])

        shipment.est_departure_date = parse_date asn.text("EstDepartDate")
        shipment.departure_date = parse_date(asn.text("ReferenceDates[ReferenceDateType = 'Departed']/ReferenceDate"))
        shipment.est_arrival_port_date = parse_date asn.text("EstDischargePortDate")
      end

      REXML::XPath.match(xml, "/Prep7501Message/Prep7501/ASN/Container").each do |container_xml|
        container = parse_container(shipment, container_xml)

        # Don't make lines if there were any errors...at this point any errors are going to have to do with missing Order / Product data..
        # So we can't make order lines...ergo, don't attempt to
        if !inbound_file.failed?
          # The data in the XML seems to come in an entirely random order.  It doesn't match the order of the
          # paper packing list or the commercial invoice (even the commercial invoice data inside this 7501 
          # doesn't match the order of the commercial invoice - it's totally random).
          # The existing feed orders the data based on the LineItemNumber (.ie the PO line number), so we'll continue
          # doing that.
          sorted_line_items(container_xml).each do |item_xml|
            parse_shipment_line(shipment, container, item_xml, orders_cache, products_cache)
          end
        end
      end

      # If the shipment was fully processed, we can mark it to be sent to the entry system
      if !inbound_file.failed?
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

  def sorted_line_items container_xml
    items = REXML::XPath.match(container_xml, "LineItems").to_a
    items.sort do |a, b|
      v = a.text("PONumber").to_s <=> b.text("PONumber").to_s

      if v == 0
        v = a.text("LineItemNumber").to_i <=> b.text("LineItemNumber").to_i
      end

      v
    end
  end

  def parse_container shipment, xml
    container = shipment.containers.build
    container.container_number = xml.text "ContainerNumber"
    container.container_size = xml.text "ContainerType"
    container.fcl_lcl = xml.text "ContainerLoad"
    container.seal_number = xml.text "SealNumber"

    container
  end

  def parse_shipment_line shipment, container, line_xml, orders_cache, products_cache
    line = shipment.shipment_lines.build
    line.container = container
    line.invoice_number = line_xml.text("InvoiceNumber")
    # The carton count on the XML is invalid...It's the piece count, not the actual # of cartons
    line.carton_qty = 0
    line.quantity = parse_decimal(line_xml.text("Quantity"))
    line.gross_kgs = parse_weight(line_xml.get_elements("Weight").first)
    line.cbms = parse_volume(line_xml.get_elements("Volume").first)
    
    order_number = line_xml.text "PONumber"
    order = orders_cache[order_number]
    if order
      product = nil
      if shipment.importer.system_code == "ADVAN"
        line_number = line_xml.text("LineItemNumber").to_i
        order_line = order.order_lines.find {|ol| ol.line_number == line_number }
        # This really should never happend at all since we're making orders / products in this parser
        inbound_file.reject_and_raise "Failed to find Order # '#{order_number}' / Line Number #{line_number}." unless order_line
      else
        product_code = line_xml.text("ProductCode")
        product = products_cache[product_code]

        order_line = order.order_lines.find {|ol| ol.product_id == product.id }

        # This really should never happend at all since we're making orders / products in this parser
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

  def find_port port_xml, lookup_type_order: [:schedule_d_code, :schedule_k_code, :unlocode]
    # The port may have Locode, Schedule D or K codes..look for D, then K, then fall back to locode
    port = nil
    Array.wrap(lookup_type_order).each do |lookup_type|
      case(lookup_type)
      when :schedule_d_code
        code = port_xml.text "CityCode[@Qualifier='D']"
      when :schedule_k_code
        code = port_xml.text "CityCode[@Qualifier='K']"
      when :unlocode
        code = port_xml.text "CityCode[@Qualifier='UN']"
      end

      if !code.blank?
        port = Port.where(lookup_type => code).first
        break if port
      end
    end

    port
  end

  def find_country port_xml
    iso_code = port_xml.text "CountryCode"
    @port ||= Hash.new do |h, k|
      h[k] = Country.where(iso_code: k).first
    end


    iso_code.blank? ? nil : @port[iso_code]
  end

  def parse_date date
    d = parse_datetime(date)
    d.nil? ? nil : d.to_date
  end

  def parse_datetime date
    return nil if date.nil?

    Time.zone.parse(date)
  end

  def parse_decimal v
    return nil if v.nil?

    BigDecimal(v)
  end

  def parse_weight xml
    val = parse_decimal(xml.try(:text))
    return nil unless val
    
    code = xml.attributes["ANSICode"]
    # I'm assuming LB and KG are the only values that are going to get sent here.
    if code == "KG"
      return val
    else
      return BigDecimal("0.453592") * val
    end
  end

  def parse_volume xml
    val = parse_decimal(xml.try(:text))
    return nil unless val

    code = xml.attributes["ANSICode"]
    # I'm assuming CR (cubic Meters) and Cubic Feet are the only values that are going to get sent here.
    if code == "CR"
      return val
    else
      return BigDecimal("0.0283168") * val
    end
  end

  def find_or_create_shipment importer, xml
    # We don't actually get a master bill for these, so we'll use the house bill as the reference
    house_bill = xml.text "/Prep7501Message/Prep7501/AggregationLevel[@Type='BL']"
    inbound_file.reject_and_raise "No Bill of Lading present." if house_bill.blank?

    last_exported_from_source = parse_datetime(xml.text "/Prep7501Message/TransactionInfo/Created")

    reference = "#{importer.system_code}-#{house_bill}"
    inbound_file.add_identifier :shipment_number, reference
    shipment = nil
    Lock.acquire(reference) do 
      s = Shipment.where(importer_id: importer.id, reference: reference).first_or_create! last_exported_from_source: last_exported_from_source
      inbound_file.set_identifier_module_info(:shipment_number, Shipment, s.id) if s

      if process_shipment?(s, last_exported_from_source)
        shipment = s
      else
        inbound_file.add_info_message "Shipment not updated: file contained outdated info."
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

  def parse_orders importer, xml, parties, products_cache, user, file
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
    customer_order_number = line_xml.text "PONumber"
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
        inbound_file.add_identifier :po_number, customer_order_number, module_type:Order, module_id:order.id
      end
    end

    product_code = line_xml.text("ProductCode")
    product = products_cache[product_code]
    Lock.db_lock(order) do
      line_number = line_xml.text("LineItemNumber").to_i
    
      if importer.system_code == "ADVAN"
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
        # that has the same product code.
        line = order.order_lines.find {|l| l.product_id == product.id }

        if line.nil?
          inbound_file.add_reject_message "PO # #{customer_order_number} is missing part number #{product_code}."
          return nil
        end
      end

      # This data is pulled from the Invoice portion of the XML..
      invoice_line = REXML::XPath.first xml, "/Prep7501Message/Prep7501/CommercialInvoice/Item[PurchaseOrderNumber='#{customer_order_number}' and ItemNumber='#{product_code}' and UserRefNumber='#{line_number}']"
      if line.nil?
        inbound_file.add_reject_message "Unabled to find Commerical Invoice Line for Order Number #{customer_order_number} / Item Number #{product_code} / Line #{line_number}"
        return nil
      end
      
      line.quantity = parse_decimal(invoice_line.text "Quantity")
      line.unit_of_measure = invoice_line.text "QuantityUOM"

      if importer.system_code == "ADVAN"
        # For whatever reason, CQ invoices don't have pricing included on them.  The unit cost needs to come from 
        # the CQ PO Origin Report (AdvancePoOriginReportParser).
        total_cost = invoice_line.get_elements("ItemTotalPrice").first
        if total_cost
          val = parse_decimal(total_cost.text)
          if line.quantity && val
            line.price_per_unit = val / line.quantity
          end

          line.currency = total_cost.attributes["Currency"]
        end
      end

      line.country_of_origin = invoice_line.get_elements("OriginCountry").first.try(:attributes).try(:[], "Code")
      
      # Pull the country of origin from the invoice line Factory PartyInfo if it's not found in an OriginCountry element
      if line.country_of_origin.blank?
        line.country_of_origin = REXML::XPath.first(invoice_line, "PartyInfo[Type = 'Factory']/CountryCode").try(:text)
      end

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
      product = find_or_create_product importer, line_item, products, user, file
    end

    products
  end

  def asn_line_items xml
    REXML::XPath.match(xml, "Prep7501Message/Prep7501/ASN/Container/LineItems").each do |line_item|
      yield line_item
    end
  end

  def find_or_create_product importer, xml, cache, user, file
    product = nil
    part_number = xml.text "ProductCode"
    return nil if part_number.blank?

    unique_identifier = "#{importer.system_code}-#{part_number}"
    Lock.acquire("Product-#{unique_identifier}") do 
      # The products SHOULD all exist already, and we don't want to update data on them if they do.
      product = Product.where(unique_identifier: unique_identifier, importer_id: importer.id).first_or_initialize

      if !product.persisted?
        product.name = xml.text "ProductName"
        product.find_and_set_custom_value cdefs[:prod_part_number], part_number

        product.save!
        product.create_snapshot user, nil, file
      end

    end
    cache[part_number] = product

    product
  end

  def parse_parties importer, xml
    parties = {}
    # Need Supplier (We'll use Ship From Address), Final Dest (We'll use Ship To, linked to Importer)
    consignee = REXML::XPath.first xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'Consignee']"
    parties[:consignee] = find_or_create_company_address(importer, consignee, {consignee: true}) if consignee

    ship_from = REXML::XPath.first xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'Supplier']"
    parties[:ship_from] = find_or_create_address(importer, ship_from) if ship_from

    ship_to = REXML::XPath.first xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'ShipmentFinalDest']"
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
    a.address_type = address_xml.text "Type"
    a.name = address_xml.text "Name"
    lines = REXML::XPath.match(address_xml, "Address/AddressLine").map &:text
    a.line_1 = lines[0]
    a.line_2 = lines[1]
    a.line_3 = lines[2]
    a.city = address_xml.text "City/CityName"
    a.state = address_xml.text "City/State"
    country_code = address_xml.text "City/CountryCode"
    a.country = Country.where(iso_code: country_code).first if !country_code.nil?
    a.postal_code = address_xml.text "PostalCode"

    a
  end

  def find_or_create_company_address importer, address_xml, company_type_hash
    address = parse_address_data(nil, address_xml)

    # Use the address hash as the system code, its the only piece of identifying information we get from the 7501 XML, and the companies we create from this
    # or pretty much solely used to convey address information to the outbound files we generate for them.
    hash = Address.make_hash_key address
    company = nil
    created = false
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
    consignee = REXML::XPath.first xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'Consignee']"
    inbound_file.reject_and_raise "Invalid XML.  No Consignee could be found." unless consignee

    name = consignee.text "Name"
    if (name =~ /Carquest/i) || (name =~ /CQ/i)
      importer = Company.where(system_code: "CQ").first
    elsif name =~ /Advance/i
      importer = Company.where(system_code: "ADVAN").first
    end

    inbound_file.reject_and_raise "Failed to find Importer account for Consignee name '#{name}'." unless importer

    importer
  end

  def cdefs
    @cdefs = self.class.prep_custom_definitions([:prod_part_number, :shp_entry_prepared_date])
  end

end; end; end; end;