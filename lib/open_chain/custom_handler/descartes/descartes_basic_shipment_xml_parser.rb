require 'open_chain/integration_client_parser'

# This is a simple header/container level parser for descartes (eCellerate) shipment data.
# The reason it only handles header / container level data is because we have some customers 
# that need us to track their shipment data at a lower / more precise level than descartes allows
# Generally this is for customers we take PO data for and 
module OpenChain; module CustomHandler; module Descartes; class DescartesBasicShipmentXmlParser
  include OpenChain::IntegrationClientParser

  def self.parse_file file, log, opts = {}
    self.new.parse(REXML::Document.new(file), User.integration)
  end

  def parse xml, user
    xml = xml.root
    inbound_file.add_identifier :house_bill, house_bill(xml)
    inbound_file.add_identifier :master_bill, master_bill(xml)
    inbound_file.company = set_importer(xml)
    
    s = nil
    find_shipment(xml) do |shipment|
      set_shipment_header_information(shipment, xml)

      REXML::XPath.each(xml, "Containers/Container").each do |cont_xml|
        find_container(shipment, cont_xml) do |container|
          set_container_information(shipment, container, cont_xml)

          REXML::XPath.each(cont_xml, "Items/Item") do |item_xml|
            # At some point, I'm pretty confident we'll have to process line level data from descartes,
            # when that happens another parser class can be written that extends this one and overrides the no-op
            # line level method below
            parse_shipment_line(shipment, container, item_xml)
          end
        end
      end

      shipment.save!
      shipment.create_snapshot user, nil, inbound_file.s3_path
      s = shipment
    end

    s
  end

  def set_shipment_header_information shipment, xml
    # These string/date/decimal methods are a little weird, the reason I wrote/used them is that since the 
    # shipment screen is used for keying data in a number of situations in addition to this eCellerate
    # feed.  I don't want blank/nil data from this xml file overwriting something someone keyed.
    # If the data is in the file, it'll take precedence, but blank/nil values will be skipped
    string(xml.text "MasterBillNumber") { |s| shipment.master_bill_of_lading = s}
    string(xml.text "TransportationMethod") { |s| shipment.mode = s}
    string(xml.text "CarrierCode") { |s| shipment.vessel_carrier_scac = s}
    string(xml.text "VesselName") { |s| shipment.vessel = s}
    string(xml.text "VoyageFlightNumber") { |s| shipment.voyage = s}
    string(xml.text "BookingNumber" ) { |s| shipment.booking_number = s }
    date(xml.text "DepartureDateTime") {|d| shipment.est_departure_date = d }
    date(xml.text "ConfirmedDepartureDate") {|d| shipment.departure_date = d }
    date(xml.text "ArrivalDateTime") { |d| shipment.est_arrival_port_date = d }

    totals = REXML::XPath.first(xml, "BLDescriptions/BLDescription")

    if totals 
      decimal(totals.text "NumberOfCartons" ) { |d| shipment.number_of_packages = d.to_i }
      string(totals.text "TypeOfCartons") { |s| shipment.number_of_packages_uom = s }
      string(totals.text "Description") { |s| shipment.description_of_goods = s }
      decimal(totals.text "GrossWeight") { |d| shipment.gross_weight = metric_weight(d, totals.text("WeightUnit")) }
      decimal(totals.text "Volume") { |d| shipment.volume = metric_volume(d, totals.text("VolumeUnit")) }
    end

    string(REXML::XPath.first(xml, "Locations/Location[LocationType = 'PlaceOfReceipt']/LocationName").try(:text)) { |s| shipment.receipt_location = s }
    port(REXML::XPath.first(xml, "Locations/Location[LocationType = 'PortOfEntry']")) {|p| shipment.destination_port = p }
    port(REXML::XPath.first(xml, "Locations/Location[LocationType = 'PortOfLoad']")) {|p| shipment.lading_port = p }
    port(REXML::XPath.first(xml, "Locations/Location[LocationType = 'PortOfDischarge']")) {|p| shipment.unlading_port = p }
    port(REXML::XPath.first(xml, "Locations/Location[LocationType = 'PlaceOfDelivery']")) {|p| shipment.final_dest_port = p }

    nil
  end

  def set_container_information shipment, container, container_xml
    string(container_xml.text "SealNumber1") { |s| container.seal_number = s }
    string(container_xml.text "EquipmentTypeCode") { |s| container.container_size = s }

    nil
  end

  def parse_shipment_line shipment, container, line_xml
    # This method should be overridden when we get to the point of having a non-basic descartes parser.
    # It will find/update the shipment line to use and set the line level attributes.
    nil
  end

  def find_shipment xml
    house_bill = house_bill(xml)
    last_exported_from_source = source_date(xml)

    inbound_file.reject_and_raise("All eCellerate shipment XML files must have a HouseBillNumber element.") if house_bill.blank?
    inbound_file.reject_and_raise("All eCellerate shipment XML files must have a TransactionDateTime element.") if last_exported_from_source.nil?

    shipment = nil
    Lock.acquire("Shipment-#{house_bill}") do 
      s = Shipment.where(house_bill_of_lading: house_bill, importer_id: importer.id).first_or_create! reference: reference_number(xml)
      if process_file?(s, last_exported_from_source)
        shipment = s
      end
    end

    if shipment
      Lock.db_lock(shipment) do 
        if process_file?(shipment, last_exported_from_source)
          shipment.last_exported_from_source = last_exported_from_source
          shipment.last_file_path = inbound_file.s3_path
          shipment.last_file_bucket = inbound_file.s3_bucket

          yield shipment
        end
      end
    end

    shipment
  end

  def find_container shipment, container_xml
    container_number = "#{container_xml.text "EquipmentInitial"}#{container_xml.text "EquipmentNumber"}"
    container = shipment.containers.find {|c| c.container_number == container_number }
    if container.nil?
      container = shipment.containers.build container_number: container_number
    end
    inbound_file.add_identifier :container_number, container_number

    yield container
  end

  def importer
    inbound_file.error_and_raise("Parser must set importer before trying to reference it.") if @importer.nil?
    @importer
  end

  def process_file? shipment, last_exported_from_source
    shipment.last_exported_from_source.nil? || shipment.last_exported_from_source <= last_exported_from_source
  end

  def set_importer xml
    importer = nil
   imp_xml = find_party(xml, "Importer")
    if imp_xml
      ecell_code = imp_xml.try(:text, "PartyCode")
      if !ecell_code.blank?
        importer = Company.where(importer: true).joins(:system_identifiers).where(system_identifiers: {system: "eCellerate", code: ecell_code}).first

        # Error on these as they're just cases where something isn't set up on our side, rather than an issue w/ the actual data in the xml file
        inbound_file.error_and_raise("Failed to find importer with eCellerate code of '#{ecell_code}'.") if importer.nil?
        inbound_file.error_and_raise("eCellerate Importer '#{ecell_code}' must have a VFI Track system code configured.") if !importer.nil? && importer.system_code.blank?
      else
        inbound_file.reject_and_raise("All eCellerate shipment XML files must have an Importer Party element with a PartyCode element.")
      end
      
      @importer = importer
    else
      inbound_file.reject_and_raise("All eCellerate shipment XML files must have an Importer Party element.")
    end

    importer
  end

  def find_party xml, party_type
    REXML::XPath.first(xml, "Parties/Party[PartyType = '#{party_type}']")
  end

  def house_bill xml
    xml.text "HouseBillNumber"
  end

  def master_bill xml
    xml.text "MasterBillNumber"
  end

  def source_date xml
    date(xml.text "TransactionDateTime") {|d| return d }
    nil
  end

  def date value
    date = Time.zone.parse value
    if date
      yield date
      return date
    end
    nil
  rescue 
    nil
  end

  def decimal value
    if !value.blank?
      v = BigDecimal(value)
      yield v
      return v
    end
    nil
  rescue
    nil
  end

  def string value
    if !value.nil?
      yield value
      return value
    end
    nil
  end

  def metric_weight v, uom
    case uom
    when /KG/i
      return v
    else
      # I'm going to assume anything else is just lbs
      v * BigDecimal("0.453592")
    end
  end

  def metric_volume v, uom
    case uom
    when /CBM/i
      return v
    else
      # I'm going to assume anything else is just cubic feet - who uses cubic feet?
      v * BigDecimal("0.0283168")
    end
  end

  def port port_xml
    return nil if port_xml.nil?

    port_type = port_xml.text "LocationIdQualifier"
    port_code = port_xml.text "LocationId"

    return nil if port_type.blank? || port_code.blank?

    port = case port_type
    when "F"
      Port.where(schedule_k_code: port_code).first
    when "D"
      Port.where(schedule_d_code: port_code).first
    else
      inbound_file.add_warning_message("Unexpected LocationIdQualifier of '#{port_type}' found.")
      nil  
    end

    if port
      yield port
      return port
    end
    nil
  end

  def reference_number xml
    # By default, we're going to use the house bill as the primary reference number as that's how the only 
    # current account we have data for has it set up.
    "#{importer_prefix}-#{house_bill(xml)}"
  end

  def importer_prefix
    prefix = importer.system_code
    if prefix == "JJILL"
      prefix = "JILL"
    end

    prefix
  end

end; end; end; end