require 'open_chain/integration_client_parser'
require 'open_chain/gpg_integration_client_parser_support'
require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_support'
require 'open_chain/custom_handler/vandegrift/catair_parser_support'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftCatair7501Parser
  include OpenChain::IntegrationClientParser
  include OpenChain::FtpFileSupport
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport
  include OpenChain::GpgIntegrationClientParserSupport
  include OpenChain::CustomHandler::Vandegrift::CatairParserSupport

  def self.parse data, opts = {}
    self.new.parse(data, opts)
  end

  def parse data, opts = {}
    Array.wrap(process_file(data)).each do |shipment|
      generate_and_send_shipment(shipment)
    end
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
      elsif rtype == "10"
        process_10(shipment, line)
      elsif rtype == "11"
        process_11(shipment, line)
      # Because the current project this is being built for does not require Master / House Bill handling
      # We're punting entirely on processing these for now (since I don't have any samples at all to go off of)
      elsif rtype == "20"
        process_20(shipment, line)
      elsif rtype == "21"
        process_21(shipment, line)
      elsif rtype == "31"
        process_31(shipment, line)
      elsif rtype == "40"
        if invoice.nil?
          invoice = new_commercial_invoice(shipment)
          shipment.invoices << invoice
        end
        current_line = new_commercial_invoice_line(shipment, invoice)
        invoice.invoice_lines << current_line
        process_40(current_line, line)
      elsif rtype == "41"
        process_41(current_line, line)
      elsif rtype == "43"
        process_43(current_line, line)
      elsif rtype == "44"
        process_44(current_line, line)
      elsif rtype == "47"
        process_47(current_line, line)
      elsif rtype == "51"
        process_51(current_line, line)
      elsif rtype == "50"
        tariff = new_commercial_invoice_tariff(shipment, invoice, current_line)
        current_line.tariff_lines << tariff
        process_50(tariff, line)
      elsif rtype == "SE61"
        process_SE61(current_line, line)
      elsif rtype == "Y"
        # Y is a trailer record and indicates the current shipment is done.
        shipments << shipment unless shipment.nil?
      end
    end

    shipments
  end

  def generate_and_send_shipment shipment
    xml = generate_entry_xml shipment
    Tempfile.open(["CI_LOAD_#{shipment.file_number}_", ".xml"]) do |file|
      xml.write file
      file.flush
      file.rewind

      ftp_file file, ecs_connect_vfitrack_net("kewill_edi/to_kewill")
    end
    nil
  end

  def process_B shipment, line
    application_code = extract_string(line, (11..12))
    # SE in 11-12 indictates an Entry Summary (7501)..if that's not there we need to reject the file because
    # it's not going to be structured as we expect it.
    inbound_file.reject_and_raise("CATAIR B-record's Application Identifier Code (Position 11-12) must be 'AE' to indicate a Entry Summary.  It was '#{application_code}'.") unless application_code  == "AE"
    nil
  end

  def process_10 shipment, line
    shipment.entry_filer_code = extract_string(line, (4..6))
    shipment.entry_number = extract_string(line, (9..16))
    shipment.entry_port = extract_integer(line, (18..21))
    shipment.entry_type = extract_string(line, (34..35))
    shipment.mode_of_transportation = extract_integer(line, (36..37))

    populate_edi_identifiers(shipment)
    nil
  end

  def process_11 shipment, line
    shipment.customer = find_customer_number("EI", extract_string(line, (3..14)))
    consignee = extract_string(line, (15..26))
    if consignee.present?
      shipment.consignee_code = find_customer_number("EI", consignee)
    end
    shipment.vessel = extract_string(line, (54..60))
    shipment.destination_state = extract_string(line, (61..62))
    nil
  end

  def process_20 shipment, line
    shipment.carrier = extract_string(line, (3..6))
    shipment.unlading_port = extract_integer(line, (7..10))
    est_arrival_date = extract_date(line, (11..16))
    if est_arrival_date
      shipment.dates << CiLoadEntryDate.new(:est_arrival_date, est_arrival_date) 
    end
    shipment.firms_code = extract_string(line, (17..20))

    # Vessel may already be filled in by the FTZ Zone ID field found on the type 11 segments
    # Don't overwrite that value
    vessel = extract_string(line, (21..40))
    shipment.vessel = vessel unless vessel.blank? || shipment.vessel.present?
    nil
  end

  def process_21 shipment, line
    shipment.voyage = extract_string(line, (3..7))
    nil
  end

  def process_31 shipment, line
    shipment.bond_type = extract_string(line, 3)
    nil
  end

  def process_40 invoice_line, line
    invoice_line.part_number = extract_string(line, (5..7))
    # The following is the set indicator (X, V)
    invoice_line.spi2 = extract_string(line, 8)
    invoice_line.country_of_origin = extract_string(line, (9..10))
    invoice_line.country_of_export = extract_string(line, (11..12))
    invoice_line.exported_date = extract_date(line, (13..18))
    invoice_line.visa_date = extract_date(line, (19..24))
    invoice_line.spi = extract_string(line, (25..26))
    invoice_line.charges = extract_integer(line, (27..36))
    invoice_line.lading_port = extract_integer(line, (37..41))
    invoice_line.gross_weight = extract_integer(line, (42..51))
    invoice_line.textile_category_code = extract_integer(line, (52..54))
    invoice_line.related_parties = extract_boolean(line, 56)
    nil
  end

  def process_41 invoice_line, line
    invoice_line.ftz_zone_status = extract_string(line, 3)
    invoice_line.ftz_priv_status_date = extract_date(line, (4..9))
    invoice_line.ftz_quantity = extract_integer(line, (10..19))
    nil
  end

  def process_43 invoice_line, line
    invoice_line.ruling_type = extract_string(line, 3)
    invoice_line.ruling_number = extract_string(line, (9..14))
    nil
  end

  def process_44 invoice_line, line
    desc = extract_string(line, (3..72))
    if invoice_line.description.blank?
      invoice_line.description = desc
    else
      invoice_line.description += " #{desc}"
    end
    nil
  end

  def process_47 invoice_line, line
    party_type = extract_string(line, 3)
    party_identifier = extract_string(line, (4..18))
    if party_type == "M"
      invoice_line.mid = party_identifier
    elsif party_type == "S" # Sold-To (AKA Buyer)
      invoice_line.buyer_customer_number = find_customer_number("EI", party_identifier)
    end
    nil
  end

  def process_50 invoice_tariff, line
    invoice_tariff.hts = extract_string(line, (3..12))
    # skipping duty amount, there's no EDI field for it to CMUS...
    # which makes sense, since CMUS should calc it based on the tariff
    # information provided.
    invoice_tariff.foreign_value = extract_integer(line, (25..34))
    invoice_tariff.quantity_1 = extract_decimal(line, (36..47))
    invoice_tariff.uom_1 = extract_string(line, (48..50))
    invoice_tariff.quantity_2 = extract_decimal(line, (51..62))
    invoice_tariff.uom_2 = extract_string(line, (63..65))
    invoice_tariff.quantity_3 = extract_decimal(line, (66..77))
    invoice_tariff.uom_3 = extract_string(line, (78..80))

    nil
  end

  def process_51 invoice_line, line
    invoice_line.visa_number = extract_string(line, (3..11))
    nil
  end

  def process_SE61 invoice_line, line
    invoice_line.ftz_expired_hts_number = extract_string(line, (5..14))
    nil
  end

  def add_special_tariffs? entry, invoice, line
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
      entry_date = shipment.dates.find {|d| d.code == :est_arrival_date }&.date
      entry_date = Time.zone.now.in_time_zone("America/New_York").to_date if entry_date.nil?
      i.invoice_date = entry_date
      i.invoice_lines = []
      i
    end

    def new_commercial_invoice_line shipment, invoice
      l = CiLoadInvoiceLine.new
      l.tariff_lines = []
      l
    end

    def new_commercial_invoice_tariff shipment, invoice, invoice_line
      t = CiLoadInvoiceTariff.new
      t.gross_weight = invoice_line.gross_weight
      t.spi = invoice_line.spi
      t.spi2 = invoice_line.spi2

      t
    end

    def new_party
      CiLoadParty.new
    end

end; end; end; end