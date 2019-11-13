require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/gt_nexus/generic_gtn_parser_support'
require 'open_chain/custom_handler/gt_nexus/generic_gtn_asn_parser_support'

module OpenChain; module CustomHandler; module GtNexus; class AbstractGtnAsnXmlParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::GtNexus::GenericGtnParserSupport
  include OpenChain::CustomHandler::GtNexus::GenericGtnAsnParserSupport
  extend OpenChain::CustomHandler::XmlHelper

  # Sets any additional customer specific information into the shipment.
  # in the generic case, this method is a no-op
  def set_additional_shipment_information shipment, shipment_xml
    nil
  end

  # Sets any additional customer specific information into the container.
  # in the generic case, this method is a no-op
  def set_additional_container_information shipment, container, container_xml
    nil
  end

  # Sets any additional customer specific information into the shipment line.
  # in the generic case, this method is a no-op
  def set_additional_shipment_line_information shipment, container, line, line_xml
    nil
  end

  # Sets any additional customer specific information into a party.
  # in the generic case, this method is a no-op
  def set_additional_party_information company, party_xml, party_type
    nil
  end

  # If there is any final information that needs to be added to the shipment before 
  # it is saved...override this method and add it.
  # This method is called after shipment totals are calculated
  def finalize_shipment shipment, shipment_xml
    nil
  end

  # Return the system code to utilize on the purchase orders.
  # It's possible that the same GT Nexus account may map to multiple of our importers,
  # ergo the need to pass the order xml.
  # This method is called once at the beginning of parsing the XML and never again.
  def importer_system_code asn_xml
    inbound_file.error_and_raise("Your customer specific class extension must implement this method, returning the system code of the importer to utilize on the Orders.")
  end

  # Return the system code to use for the party xml given.  
  # DO NOT do any prefixing (like w/ the importer system code), the caller will handle all of that
  # for you.  Just return the identifying information for the party using the provided XML party element.
  def party_system_code party_xml, party_type
    # I'm pretty sure in the vast majority of cases we should be using customer specific identifiers
    # inside the identification element...those appear to be 100% customer specific though and not 
    # generic, so we'll have to have this be overriden to determine which internal code in the party object should
    # be used in all cases.
    inbound_file.error_and_raise("This method must be overriden by an implementing class.")
  end

  def initialize configuration
    # In general, you'll want to set this to false on customer specific systems (ll, polo, etc)
    @prefix_identifiers_with_system_codes = configuration[:prefix_identifiers_with_system_codes].nil? ? true : configuration[:prefix_identifiers_with_system_codes]

    @create_missing_purchase_orders = configuration[:create_missing_purchase_orders].nil? ? false : configuration[:create_missing_purchase_orders]
  end

  def prefix_identifiers_with_system_codes?
    @prefix_identifiers_with_system_codes
  end

  def create_missing_purchase_orders?
    @create_missing_purchase_orders
  end

  def self.parse_file data, log, opts = {}
    xml = xml_document data

    user = User.integration

    inbound_file.reject_and_raise("Unexpected root element. Expected ASNMessage but found '#{xml.root.name}'.") unless xml.root.name == "ASNMessage"

    # I don't believe GTN actually exports multiple ASN's per XML document, they use the
    # same schema for uploading to them and downloading from them, so the functionality is 
    # there to send them mulitple ASN's, but as to getting them exported to us on event triggers,
    # I don't think we get more than one per XML document
    REXML::XPath.each(xml.root, "/ASNMessage/ASN") do |asn|
      self.process_asn(asn, user, opts[:bucket], opts[:key])
    end

  end

  # Process a single ASN element from the file
  def self.process_asn xml, user, bucket, key
    parser = self.new

    if parse_function_code(xml) == :cancel
      return parser.process_asn_cancel xml, user, bucket, key
    else
      return parser.process_asn_update xml, user, bucket, key
    end
  end

  # Determine the type of processing to do for the order, cancel or update
  def self.parse_function_code xml
    function_code = xml.text("PurposeCode").to_s
    if (function_code =~ /Delete/i)
      return :cancel
    else
      return :update
    end
  end

  # Processes a Delete purpose code, canceling the shipment.
  def process_asn_cancel xml, user, bucket, key
    set_importer_system_code(xml)
    
    shipment = find_shipment_relation(xml).first
    return unless shipment

    s = nil
    Lock.db_lock(shipment) do
      sent_date = xml_sent_date(xml)
      if process_file?(shipment, sent_date)
        set_shipment_file_metadata(shipment, sent_date, bucket, key)
        # Cancel shipment saves and snapshots a shipment
        shipment.cancel_shipment! user, canceled_date: sent_date, snapshot_context: key
        s = shipment
      end
    end
    s
  end

  # Processes a create/update purpose code.  This will be a full replace of any container 
  # referenced in the XML.
  def process_asn_update xml, user, bucket, key
    # We're going to take the approach that one ASN document maps to a single shipment in VFI Track.
    # If the data needs to be sent to Kewill, then on the backend we can handle joining multiple shipments
    # together in the CI Load process to form the entry shipment in Kewill.
    set_importer_system_code(xml)
    s = nil

    parties = parse_parties(xml, user, key)
    orders = create_order_cache(xml, user, key)

    find_or_create_shipment(xml, bucket, key) do |shipment|
      set_parties(shipment, parties)
      set_shipment_information(shipment, xml)

      process_containers(shipment, xml, orders)

      set_shipment_totals(shipment, xml)

      finalize_shipment(shipment, xml)

      # If there's any reject messages at this point we'll log a reject, which will roll back any updates done already
      inbound_file.reject_and_raise("All errors must be fixed before this ASN can be processed.") if inbound_file.failed?
      shipment.save!
      shipment.create_snapshot user, nil, key
      s = shipment
    end

    s
  end

  # Sets the basic shipment header information
  # To add more to the parsing, override the set_additional_shipment_information method
  def set_shipment_information shipment, xml
    shipment.voyage = xml.text "Voyage"
    shipment.vessel = vessel(xml)
    shipment.mode = ship_mode(xml)
    shipment.vessel_carrier_scac = carrier_code(xml)
    shipment.master_bill_of_lading = find_master_bill(xml)
    # House Bill is at the LineItem level..just pull the first one listed in the document
    # They should all be the same.
    shipment.house_bill_of_lading = xml.text "Container/LineItems/BLNumber"
    shipment.country_origin = find_port_country(REXML::XPath.first xml, "OriginCity")
    shipment.country_export = find_port_country(REXML::XPath.first xml, "PortOfLoading")
    shipment.country_import = find_port_country(REXML::XPath.first xml, "BLDestination")

    shipment.lading_port = find_port(REXML::XPath.first xml, "PortOfLoading")
    shipment.unlading_port = find_port(REXML::XPath.first xml, "PortOfDischarge")
    shipment.final_dest_port = find_port(REXML::XPath.first(xml, "BLDestination"), lookup_type_order: [:unlocode, :schedule_k_code, :schedule_d_code, :iata_code])

    shipment.est_departure_date = parse_date xml.text("EstDepartDate")
    shipment.est_arrival_port_date = parse_date xml.text("EstDischargePortDate")

    set_additional_shipment_information shipment, xml

    inbound_file.add_identifier(:master_bill, shipment.master_bill_of_lading) unless shipment.master_bill_of_lading.blank?
    inbound_file.add_identifier(:house_bill, shipment.house_bill_of_lading) unless shipment.house_bill_of_lading.blank?

    nil
  end

  # Sets the basic container information
  # To add more to the parsing, override the set_additional_container_information method
  def set_container_information shipment, container, xml
    container.container_number = xml.text "ContainerNumber"
    container.container_size = xml.text "ContainerType"
    container.fcl_lcl = xml.text "ContainerLoad"
    container.seal_number = xml.text "SealNumber"

    set_additional_container_information shipment, container, xml

    inbound_file.add_identifier(:container_number, container.container_number) unless container.container_number.blank?

    nil
  end

  # Sets the basic line level information
  # To add more to the parsing, override the set_additional_shipment_line_information method
  def set_shipment_line_information shipment, container, line, line_xml, orders_cache
    line.invoice_number = line_xml.text "InvoiceNumber"
    cartons = line_xml.text "PackageCount"
    line.carton_qty = cartons.to_i unless cartons.nil?
    line.quantity = parse_decimal(line_xml.text("Quantity"))
    line.gross_kgs = parse_weight(line_xml.get_elements("Weight").first)
    line.cbms = parse_volume(line_xml.get_elements("Volume").first)
    
    po_number = line_xml.text "PONumber"

    order_number = prefix_identifier_value(importer, po_number)
    order = orders_cache[order_number]
    if order.nil?
      inbound_file.add_reject_message("PO Number '#{po_number}' could not be found.")
      return
    end

    order_line = find_order_line(order, line_xml)
    line.product = order_line.product
    line.variant = order_line.variant
    line.linked_order_line_id = order_line.id

    set_additional_shipment_line_information shipment, container, line, line_xml

    inbound_file.add_identifier(:po_number, order.customer_order_number, module_type: Order, module_id: order.id) unless order.customer_order_number.blank?
    inbound_file.add_identifier(:invoice_number, line.invoice_number) unless line.invoice_number.blank?

    nil
  end

  # Totals all information on the shipment from the lines into the header
  def set_shipment_totals shipment, xml
    shipment.gross_weight = BigDecimal("0")
    shipment.volume = BigDecimal("0")
    shipment.number_of_packages = 0
    shipment.number_of_packages_uom = "CTN"

    shipment.shipment_lines.each do |line|
      shipment.gross_weight += line.gross_kgs if line.gross_kgs
      shipment.volume += line.cbms if line.cbms
      shipment.number_of_packages += line.carton_qty if line.carton_qty
    end

    nil
  end

  # Processes all the Container elements in the xml
  def process_containers shipment, xml, orders_cache
    REXML::XPath.each(xml, "Container") do |container_xml|
      container = find_or_create_container(shipment, container_xml)
      set_container_information(shipment, container, container_xml) unless container.nil?

      # Nearest I can tell, GT Nexus does NOT have a unique identifier on the LineItem..
      # It appears like we could use LoadSequence as a line number, but the xml is output
      # out of order and it's probably not the order we want to display the lines in.

      # SO...we're just going to destroy and recreate the shipment lines inside the present container
      shipment.shipment_lines.each do |line|
        line.destroy if container.nil? || line.container.try(:container_number) == container.container_number
      end

      sorted_line_items(container_xml).each do |line_xml|
        line = shipment.shipment_lines.build
        line.container = container
        set_shipment_line_information shipment, container, line, line_xml, orders_cache
      end
    end
  end

  def find_or_create_container shipment, container_xml
    container_number = container_xml.text "ContainerNumber"
    return if container_number.blank?

    # From what I can tell, GT Nexus does not give you a d
    container = shipment.containers.find {|c| c.container_number == container_number }
    if container.nil?
      container = shipment.containers.build container_number: container_number
    end

    container
  end

  # Orders the LineItem elements from a single Container element.  By 
  # By default, the ordering is in alphabetical order based on the InvoiceNumber, PONumber, LineItemNumber.
  # This is intended to match what appears to be the default ordering of the commercial invoice printout
  # from the GT Nexus system - which is generally what operations uses to key, validate the entry data.
  # by sorting the lines in this order, it should help them.
  #
  # This method can easily be overridden if you want to return LineItems in a different order
  # for a specific customer parser implementation.
  def sorted_line_items container_xml
    # The document order of the xml LineItems 
    # doesn't appear to represent any sort of actual order of any sort.
    #
    # This is an attempt to emulate the order that it appears that default GT Nexus
    # commercial invoices are printed in - this can make validating the data sent to Kewill
    # (or shown on screen) easier for operations.
    items = REXML::XPath.match(container_xml, "LineItems").to_a
    items.sort do |a, b|
      v = a.text("InvoiceNumber").to_s <=> b.text("InvoiceNumber").to_s

      if v == 0
        v = a.text("PONumber").to_s <=> b.text("PONumber").to_s
      end

      if v == 0
        v = a.text("LineItemNumber").to_i <=> b.text("LineItemNumber").to_i
      end

      v
    end
  end

  def find_or_create_shipment xml, bucket, key
    shipment = nil
    sent_date = xml_sent_date(xml)
    Lock.acquire("Shipment-#{shipment_reference(xml)}") do 
      s = find_shipment_relation(xml).first_or_create!

      if process_file? s, sent_date
        shipment = s
      end
    end

    if shipment
      Lock.db_lock(shipment) do
        if process_file? shipment, sent_date
          shipment.importer_reference = shipment_reference(xml)
          inbound_file.add_identifier :shipment_number, shipment.importer_reference, module_type: Shipment, module_id: shipment.id
          set_shipment_file_metadata(shipment, sent_date, bucket, key)
          yield shipment
        else
          shipment = nil
        end
      end
    end

    shipment
  end

  def create_order_cache xml, user, key
    orders = nil
    cache = {}
    order_numbers = extract_order_numbers(xml)
    orders = find_orders(order_numbers)
    Array.wrap(orders).each {|o| cache[o.order_number] = o }

    if create_missing_purchase_orders?
      order_numbers.each do |customer_order_number|
        order_number = prefix_identifier_value(importer, customer_order_number)
        # If the order is already found, it's possible there's lines missing, so check those and add them
        # otherwise, if it's not found create it.
        cache[order_number] = create_or_update_order(importer, user, xml, customer_order_number, cache[order_number])
      end
    end
    
    return cache
  end

  def extract_order_numbers xml
    Set.new(REXML::XPath.each(xml, "Container/LineItems/PONumber").map &:text).to_a
  end

  def find_orders order_numbers
    order_numbers = Array.wrap(order_numbers).map {|n| prefix_identifier_value(importer, n) }
    Order.where(order_number: order_numbers, importer_id: importer.id).includes(:order_lines).all
  end

  def find_order_line order, item_xml, reject_if_not_found: true
    # Use the raw line item number value (w/ extra leading zeros) in the message
    xml_line = item_xml.text("LineItemNumber")
    line_number = order_line_item_number(item_xml)

    line = order.order_lines.find {|l| l.line_number == line_number }
    inbound_file.reject_and_raise("Failed to find PO Line Number '#{xml_line}' on PO Number '#{order.customer_order_number}'.") if line.nil? && reject_if_not_found

    line
  end

  def process_file? shipment, sent_date
    shipment.last_exported_from_source.nil? || shipment.last_exported_from_source <= sent_date
  end

  def set_shipment_file_metadata shipment, sent_date, bucket, key
    shipment.last_exported_from_source = sent_date
    shipment.last_file_bucket = bucket
    shipment.last_file_path = key
    nil
  end

  def update_party_information? party, party_xml, party_type
    # By default, we're not going to update party data...the purchase orders are what will update these
    # entities.  

    # This overrides a method defined in generic_gtn_parser_support
    false
  end

  def party_map  
    # The only real company it makes sense to handle by default for the shipment is the vendor.
    {vendor: "PartyInfo[Type = 'Supplier']"}
  end

  def party_company_name party_xml, party_type
    party_xml.text "Name"
  end

  # For some reason, GTN ASN parties are structured differently than Orders or Invoices
  # handle the difference here
  def parse_address_info company, party_xml, party_address_type, address_system_code: nil
    address_system_code = company.system_code if address_system_code.nil?

    a = company.addresses.find {|a| a.system_code == address_system_code }

    if a.nil?
      a = company.addresses.build system_code: address_system_code
    end

    a.name = party_xml.text "Name"
    a.address_type = party_address_type
    lines = REXML::XPath.match(party_xml, "Address/AddressLine").map &:text
    a.line_1 = lines[0]
    a.line_2 = lines[1]
    a.line_3 = lines[2]

    a.city = party_xml.text "City/CityName"
    a.state = party_xml.text "City/State"
    country_code = party_xml.text "City/CountryCode"
    if !country_code.nil?
      a.country = Country.where(iso_code: country_code).first 
    else
      a.country = nil
    end
    a.postal_code = party_xml.text "PostalCode"

    a
  end

  def find_shipment_relation xml
    Shipment.where(importer_id: importer.id, reference: prefix_identifier_value(importer, shipment_reference(xml)))
  end

  def shipment_reference xml
    xml.text "ShipmentID"
  end

  def xml_sent_date xml
    # There doesn't appear to be any sort of versioning inside the ASN itself, the best we can really do is
    # just record the GT Nexus xml timestamp and work from that.
    created = xml.root.text "TransactionInfo/Created"
    created_date = Time.zone.parse(created.to_s)
    inbound_file.reject_and_raise("All GT Nexus ASNMessage documents must have a valid TransactionInfo/Created value.") if created_date.nil?
    created_date
  end

  def find_master_bill xml
    master_bill = xml.text "Container/LineItems/MasterBLNumber"

    if !master_bill.blank? && append_carrier_code_to_master_bill?(xml)
      carrier_code = xml.text "PartyInfo[Type = 'Carrier']/Code"
      master_bill = carrier_code + master_bill unless carrier_code.blank? || master_bill.starts_with?(carrier_code)
    end

    master_bill
  end

  def ship_mode xml
    xml.text "Mode"
  end

  def vessel xml
    xml.text "Vessel"
  end

  def carrier_code xml
    # Use the Party carrier code for anything other than Air (This might change once we start seeing more documents)
    # For air, we'll extract the first 2 digits of the Vessel (.ie the airline code)
    if (ship_mode(xml).to_s =~ /Air/i)
      v = vessel(xml)
      v.to_s[0, 2]
    else
      xml.text "PartyInfo[Type = 'Carrier']/Code"
    end
  end

  def append_carrier_code_to_master_bill? xml
    # By default, Ocean is going to be the only mode we append the carrier code to the master bill for.
    # This method is very easily overridden for customer specific use cases/weirdness
    (ship_mode(xml).to_s =~ /Ocean/i) ? true : false
  end

  def create_or_update_order importer, user, xml, order_number, order
    # Find all LineItems in the XML that have the specified order number, then pass them to the 'actual'
    # create order method along with the lines.
    line_items = REXML::XPath.each(xml, "Container/LineItems[PONumber = '#{order_number}']").to_a
    create_or_update_order_from_line_items(importer, user, line_items, order)
  end

  def create_or_update_order_from_line_items(importer, user, line_items, order)
    product_cache = find_or_create_products_from_line_items(importer, user, line_items)
        
    if order.nil?
      new_order, order = find_or_create_order_from_line_item(importer, user, line_items.first)
    else
      new_order = false
    end

    new_lines = false
    line_items.each do |line_item|
      # If the line was already created, dont bother with it
      order_line = find_order_line(order, line_item, reject_if_not_found: false)
      if order_line.nil?
        find_or_create_order_line_from_line_item(importer, product_cache, order, line_item)
        new_lines = true
      end
    end

    if new_order || new_lines
      order.save!
      order.create_snapshot user, nil, inbound_file.s3_path
    end

    order
  end

  def find_or_create_order_from_line_item(importer, user, line_item)
    raw_order_number = line_item.text("PONumber")
    order_number = prefix_identifier_value(importer, raw_order_number)
    find_or_create_order(importer, order_number, raw_order_number)
  end

  def find_or_create_order_line_from_line_item(importer, product_cache, order, line_item)
    order_line = order.order_lines.build

    order_line.line_number = order_line_item_number(line_item)
    order_line.product = product_cache[prefix_identifier_value(importer, line_item.text("ProductCode"))]

    order_line
  end

  def find_or_create_order importer, order_number, raw_order_number
    order = nil
    new_order = false
    Lock.acquire("Order-#{order_number}") do
      order = Order.where(order_number: order_number, importer_id: importer.id).first_or_initialize
      if !order.persisted?
        # If we're prefixing then we should copy the "raw" order number into the customer order number field
        if prefix_identifiers_with_system_codes?
          order.customer_order_number = raw_order_number
        end
        new_order = true
        order.save!
      end
    end
    [new_order, order]
  end

  def find_or_create_products_from_line_items importer, user, line_items
    parts_cache = {}
    line_items.each do |line_item|
      part_number = line_item.text("ProductCode").to_s
      unique_identifier = prefix_identifier_value(importer, part_number)
      next unless parts_cache[unique_identifier].nil? 

      parts_cache[unique_identifier] = find_or_create_product(importer, user, unique_identifier, part_number)
    end

    parts_cache
  end

  def find_or_create_product importer, user, unique_identifier, part_number
    product = nil
    Lock.acquire("Product-#{unique_identifier}") do 
      product = Product.where(importer_id: importer.id, unique_identifier: unique_identifier).first_or_initialize
      if !product.persisted?
        # If we're prefixing identifiers, it means that we're tracking the part number separately w/ a custom value too, so make sure to set it.
        product.find_and_set_custom_value(cdefs[:prod_part_number], part_number) if prefix_identifiers_with_system_codes?

        product.save!
        product.create_snapshot user, nil, inbound_file.s3_path
      end
    end

    product
  end

  def order_line_item_number xml
    xml.text("LineItemNumber").to_i
  end

  def generic_cdef_uids
    [:prod_part_number]
  end

end; end; end; end