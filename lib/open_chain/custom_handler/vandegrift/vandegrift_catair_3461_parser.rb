require 'open_chain/integration_client_parser'
require 'open_chain/gpg_integration_client_parser_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_sender_support'
require 'open_chain/custom_handler/vandegrift/catair_parser_support'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftCatair3461Parser
  include OpenChain::IntegrationClientParser
  include OpenChain::GpgIntegrationClientParserSupport
  include OpenChain::CustomHandler::Vandegrift::CatairParserSupport
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSenderSupport

  def self.parse data, opts = {}
    self.new.parse(data, opts)
  end

  def parse data, _opts = {}
    shipments = process_file(data)
    generate_and_send_shipment_xml(shipments)
    send_email_notification(shipments, "3461")
    nil
  end

  def process_file data
    shipment = nil
    invoice = nil
    current_party = nil
    current_line = nil

    shipments = []

    data.each_line do |line|
      rtype = record_type(line)
      # We're not going to bother with the A/Z line types
      if rtype == "B"
        # when a B record comes in (which should be the second line in the file)
        # we'll reset everything and then start building a new shipment
        shipment = new_shipment
        invoice = nil
        current_party = nil
        current_line = nil

        process_B(shipment, line)
      elsif rtype == "SE10"
        process_SE10(shipment, line)
      elsif rtype == "SE11"
        process_SE11(shipment, line)
      elsif rtype == "SE40"
        if invoice.nil?
          invoice = new_commercial_invoice(shipment)
          shipment.invoices << invoice
        end
        current_line = new_commercial_invoice_line(shipment, invoice)
        invoice.invoice_lines << current_line
        process_SE40(current_line, line)
      elsif rtype == "SE41"
        process_SE41(current_line, line)
      elsif rtype == "SE50"
        current_party = new_party
        current_line.parties ||= []
        current_line.parties << current_party

        process_SE30_50(current_party, line)
      elsif rtype == "SE55"
        process_SE35_55(current_party, line)
      elsif rtype == "SE56"
        process_SE36_56(current_party, line)
      elsif rtype == "SE60"
        process_SE60(current_line, line)
      elsif rtype == "SE61"
        process_SE61(current_line, line)
      elsif rtype == "Y"
        # Y is a trailer record and indicates the current shipment is done.
        shipments << shipment unless shipment.nil?
      end
    end

    shipments.each {|s| postprocess_shipment(s) }
    shipments
  end

  def postprocess_shipment shipment
    strip_entry_number(shipment)
    nil
  end

  def process_B _shipment, line # rubocop:disable Naming/MethodName
    application_code = extract_string(line, (11..12))
    # SE in 11-12 indictates a Cargo Release (3461)..if that's not there we need to reject the file because
    # it's not going to be structured as we expect it.
    inbound_file.reject_and_raise("CATAIR B-record's Application Identifier Code (Position 11-12) must be 'SE' to indicate a Cargo Release.  It was '#{application_code}'.") unless application_code == "SE" # rubocop:disable Layout/LineLength
    nil
  end

  def process_SE10 shipment, line # rubocop:disable Naming/MethodName
    shipment.entry_filer_code = extract_string(line, (6..8))
    shipment.entry_number = extract_string(line, (11..18))
    shipment.entry_type = extract_string(line, (20..21))
    ior_type = extract_string(line, (22..24))
    ior_identifier = extract_string(line, (25..36))
    shipment.customer = find_customer_number(ior_type, ior_identifier, log_customer_to_inbound_file: true)
    shipment.customs_ship_mode = extract_integer(line, (37..38))
    shipment.bond_type = extract_integer(line, 39)
    shipment.total_value_us = extract_integer(line, (40..49))
    shipment.entry_port = extract_integer(line, (50..54))
    shipment.unlading_port = extract_integer(line, (56..60))

    populate_edi_identifiers(shipment, "3461")

    nil
  end

  def process_SE11 shipment, line # rubocop:disable Naming/MethodName
    # There is no CMUS EDI field for the Entry Date Election Code (which is only present
    # for FTZ entries) and would have a value of W
    elected_entry_date = extract_date(line, (6..11), date_format: date_format)
    if elected_entry_date
      shipment.dates << CiLoadEntryDate.new(:elected_entry_date, elected_entry_date)
    end

    shipment.firms_code = extract_string(line, (12..15))
    # Elected Exam Site is not parsed (16-19)
    shipment.vessel = extract_string(line, (20..39))
    shipment.voyage = extract_string(line, (40..44))
    # General Order # - Originating Warehouse Entry Number is not parsed
    nil
  end

  def process_SE40 invoice_line, line # rubocop:disable Naming/MethodName
    invoice_line.part_number = extract_string(line, (5..7))
    invoice_line.country_of_origin = extract_string(line, (8..9))
    invoice_line.description = extract_string(line, (11..80))
    nil
  end

  def process_SE41 invoice_line, line # rubocop:disable Naming/MethodName
    invoice_line.ftz_zone_status = extract_string(line, 5)
    invoice_line.ftz_priv_status_date = extract_date(line, (6..11), date_format: date_format)
    invoice_line.ftz_quantity = extract_integer(line, (12..19))
    nil
  end

  def process_SE30_50 party, line # rubocop:disable Naming/MethodName
    party.qualifier = extract_string(line, (5..7))
    party.name = extract_string(line, (8..42))
    # We're going to (ab)use the id qualifier in the Catair spec
    # to allow sending of the MID code along with the Manufacturer party
    # information.  Normally, the spec states that you would only send
    # either a name or a qualifier/code and their is no qualifier for MID.
    # We have agreed with Integration Point (IP) to extend the spec
    # and send us the MID here with an id qualifier of MID.
    if party.qualifier.to_s.upcase == "MF"
      id_qualifier = extract_string(line, (43..45))
      if id_qualifier == "MID"
        party.mid = extract_string(line, (46..65))
      end
    end
    nil
  end

  def process_SE35_55 party, line # rubocop:disable Naming/MethodName
    # Just add the address info progressively into the party's address 1 - 3 fields
    # (Don't add it if it's a copy of existing lines)
    # Also, each 35 / 55 record can have 2 data elements per record.
    # I'm going to combine them together into a single address element in the party address if they're both present
    addr = extract_string(line, (7..41))
    addr_2 = extract_string(line, (44..78))

    if addr_2.present?
      addr += " #{addr_2}"
    end

    # Some customers seem to copy the same address data into mutiple lines, so just ignore what we've
    # extracted if it matches data we've already previously extracted
    return if addr.blank? || matches_existing_address_line?(party, addr)

    # Replace an existing field if the new address is a superset of the existing value
    if !replaces_existing_line?(party, addr)
      # Just drop the value into the first blank address 1-3 field from the party
      if party.address_1.blank?
        party.address_1 = addr
      elsif party.address_2.blank?
        party.address_2 = addr
      elsif party.address_3.blank?
        party.address_3 = addr
      end
    end

    nil
  end

  def matches_existing_address_line? party, incoming_address
    up_address = incoming_address.upcase

    [party.address_1, party.address_2, party.address_3].each do |address|
      next if address.blank?

      # If the new address line we're checking matches (or is a subset of) a previous line we've seen
      # then skip it
      return true if address.upcase.starts_with?(up_address)
    end

    false
  end

  def replaces_existing_line? party, incoming_address
    up_address = incoming_address.upcase

    [:address_1, :address_2, :address_3].each do |m|
      addr = party.public_send(m).to_s.upcase
      next if addr.blank?

      # If the new address is a superset of the existing address, then replace it
      if up_address.starts_with? addr
        party.public_send("#{m}=", incoming_address)
        return true
      end
    end

    false
  end

  def process_SE36_56 party, line # rubocop:disable Naming/MethodName
    party.city = extract_string(line, (5..39))
    party.country_subentity = extract_string(line, (40..42))
    party.zip = extract_string(line, (49..63))
    party.country = extract_string(line, (64..65))
    nil
  end

  def process_SE60 invoice_line, line # rubocop:disable Naming/MethodName
    invoice_line.hts = extract_string(line, (5..14))
    invoice_line.foreign_value = extract_integer(line, (15..24))
    nil
  end

  def process_SE61 invoice_line, line # rubocop:disable Naming/MethodName
    invoice_line.ftz_expired_hts_number = extract_string(line, (5..14))
    nil
  end

  def add_special_tariffs? _entry, _invoice, _line
    # We might want to change this so that it does add special tariffs for standard entry types...
    # but I'm not actually sure if we're expecting the Catair to even include the 301's or not...so for
    # now, since I know the FTZ entries we currently process with this parser shouldn't include supplemental tariffs
    # I'm shutting this off for all processes utilizing this parser.
    false
  end

  protected

    # The following methods are protected to allow for potential extending classes to
    # override/extend them for potential customer specific handling (if needed)
    def new_shipment
      s = CiLoadEntry.new
      s.invoices = []
      s.containers = []
      s.dates = []
      s
    end

    def new_commercial_invoice shipment
      i = CiLoadInvoice.new
      i.invoice_number = compose_full_entry_number(shipment).join("-")
      # Use the entry date as the CI Date if given (otherwise just fall back to the current date)
      # The actual date doesn't really matter (aside from it being part of the invoice key in CMUS)
      # as it's not part of the data sent in the 3461 to Customs - in fact there's no actual
      # concept of an invoice on the 3461
      entry_date = shipment.dates.find {|d| d.code == :elected_entry_date }&.date
      entry_date = Time.zone.now.in_time_zone("America/New_York").to_date if entry_date.nil?
      i.invoice_date = entry_date
      i.invoice_lines = []
      i
    end

    def new_commercial_invoice_line _shipment, _invoice
      CiLoadInvoiceLine.new
    end

    def new_party
      CiLoadParty.new
    end

end; end; end; end