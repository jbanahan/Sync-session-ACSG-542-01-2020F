require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_sender_support'
require 'open_chain/custom_handler/fixed_position_parser_support'
require 'open_chain/custom_handler/target/target_support'
require 'open_chain/custom_handler/target/target_custom_definition_support'

module OpenChain; module CustomHandler; module Target; class TargetEntryInitiationFileParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::FixedPositionParserSupport
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSenderSupport
  include OpenChain::CustomHandler::Target::TargetSupport
  include OpenChain::CustomHandler::Target::TargetCustomDefinitionSupport

  def self.parse data, opts = {}
    self.new.parse(data, opts)
  end

  def parse data, _opts = {}
    generate_and_send_shipment_xml(process_file(data))
    nil
  end

  def process_file data
    shipment = nil
    invoice = nil

    shipments = []
    data.each_line do |line|
      rtype = record_type(line)
      if rtype == "01"
        # when a B record comes in (which should be the second line in the file)
        # we'll reset everything and then start building a new shipment
        shipment = new_shipment
        shipments << shipment

        invoice = nil
        process_01(shipment, line)
      elsif rtype == "02"
        process_02(shipment, line)
      elsif rtype == "03"
        # Each shipment 01-04 data set is only ever going to have a single invoice on it
        invoice ||= begin
          i = new_commercial_invoice(shipment)
          shipment.invoices << i
          i
        end

        # There's nothing we actually need on the 03 line, which is just Purchase Order Information.
        # The PO information we actually need is repeated on the Item level (04) line anyway
      elsif rtype == "04"
        lines = process_04(shipment, invoice, line)
        invoice.invoice_lines.push(*lines)
      end
    end
    shipments.each {|s| finalize_shipment(s) }

    shipments
  end

  def process_01 shipment, line
    shipment.customer = customer_number
    bill_number = extract_string(line, (5..34))
    master_bill_number = extract_string(line, (35..64))
    inbound_file.add_identifier :master_bill, master_bill_number
    shipment.customs_ship_mode = extract_integer(line, (65..66))

    # Target's spec is a little ambiguous about the bills of lading.
    # They refer to the first field as the Bill of Lading and then the second
    # as the master bill.  However, every sample we have has the same value for
    # both.  While for Air (which we don't currently get), they have the second as the Master Air Waybill
    # and the first as the House.
    # For Ocean / Truck..I'm going to assume if the bills are different the first is the house
    # and the second is the Master.  If they're the same, I'm just going to send a Master Bill
    # For Air, I'm going to follow what the spec says.
    bol = CiLoadBillsOfLading.new
    shipment.bills_of_lading << bol

    if Entry.get_transport_mode_codes_us_ca("AIR").include?(shipment.customs_ship_mode)
      bol.house_bill = bill_number

      if bill_number != master_bill_number
        bol.master_bill = master_bill_number
      end
    else
      bol.master_bill = master_bill_number
      if bill_number != master_bill_number
        bol.house_bill = bill_number
      end
    end

    shipment.vessel = extract_string(line, (67..101))
    shipment.voyage = extract_string(line, (102..106))
    if shipment.voyage.present?
      # Strip trailing hyphens (which are present for some reason)
      shipment.voyage.gsub!(/-+$/, "")
    end
    shipment.country_of_export = extract_string(line, (107..109))
    shipment.lading_port = extract_string(line, (110..114))
    shipment.unlading_port = extract_string(line, (115..118))
    # Target apparently isn't going to do In-Bond (where you offload at an ocean port
    # and then do the entry at an inland port)...so we can assume the port of entry
    # is the same as the unlading port.  Even if they did occasionally, this is only
    # a single field on the header to adjust, not a big deal.
    shipment.entry_port = shipment.unlading_port
    add_entry_date(shipment, line, (119..126), [:export_date])
    add_entry_date(shipment, line, (127..134), [:est_arrival_date, :arrival_date, :import_date])
    shipment.charges = extract_decimal(line, (135..147), decimal_places: 3)
    shipment.carrier = extract_string(line, (148..151))
    shipment.weight_kg = extract_decimal(line, (152..164), decimal_places: 3).round(0, BigDecimal::ROUND_HALF_UP)

    if extract_string(line, (165..167)) == "001"
      shipment.recon_value_flag = true
    end

    nil
  end

  def process_02 shipment, line
    container_number = extract_string(line, 35..48)
    if container_number.present?
      shipment.containers << CiLoadContainer.new(container_number)
    end

    nil
  end

  def process_04 shipment, invoice, line
    # dpci is basically the unique item number for Target (DPCI = DePartment / Class / Item)
    # Vendor Order Point is essentially a code for the Factory.  Because some tariff data
    # differs between factories, we're having to concatenate the two together to make a fully
    # unique part number in CM.
    vendor_order_point = extract_string(line, (47..55))
    dpci = extract_string(line, (56..64))
    part_number = build_part_number(dpci, vendor_order_point)
    part = find_target_part(part_number)

    lines = []
    if xvv_set_part?(part)
      tariffs = part.classifications.where(country_id: us.id).first&.tariff_records
      tariffs.each do |tariff|
        xvv = tariff.custom_value(cdefs[:tar_xvv]).to_s.upcase
        next unless ["X", "V"].include?(xvv)

        invoice_line = new_commercial_invoice_line(shipment, invoice)
        invoice_line.part_number = part_number
        process_invoice_line(shipment, invoice, invoice_line, line, part)

        invoice_line.hts = tariff.hts_1
        invoice_line.spi2 = xvv

        lines << invoice_line
      end
    end

    # If for some reason the part looked like a set but didn't have any XVV lines or
    # anything, then just handle it like a standard line
    if lines.blank?
      invoice_line = new_commercial_invoice_line(shipment, invoice)
      invoice_line.part_number = part_number
      process_invoice_line(shipment, invoice, invoice_line, line, part)
      lines << invoice_line
    end

    lines
  end

  def finalize_shipment shipment
    # Clear the header leavel country of export (we copied it down to the line level)
    shipment.country_of_export = nil
    # Strip the charges out of the shipment (since we copied to the invoice)
    shipment.charges = nil
  end

  def add_special_tariffs? _entry, _invoice, _line
    # Don't add 301 tariffs to the feed...I'm presuming that Target will have
    # them already in the parts data.
    false
  end

  private

    def process_invoice_line shipment, _invoice, inv_line, line, part
      po = extract_string(line, (35..46))
      # Target's PO # comes in like 0032-266381.
      # Where 0032 is the department and 266381 is the PO #.
      # So split those out if the PO matches this format
      if po =~ /\A([^-]+)-(.+)/
        inv_line.department = Regexp.last_match(1)
        inv_line.po_number = Regexp.last_match(2)
      else
        inv_line.po_number = po
      end

      inbound_file.add_identifier :po_number, inv_line.po_number

      inv_line.cartons = extract_integer(line, (65..73))
      inv_line.pieces = extract_integer(line, (83..91))

      # If the part is an assortment, then we're going to send a UOM of PKG as an indicator
      # of sorts to operations that this part is a set (essentially it's a part number that
      # has multiple components in it, but for customs purposes we're only tracking the outer
      # quantity - not the inner number of pieces).  So, like you could have a bag of socks
      # where there's 6 pairs of socks but what we care about for customs is just that
      # bag, not the 6 pairs inside it.  Operations wants to know this so they can more
      # easily know which quantity on the commercial invoice they should be tracking.
      if assortment_part?(part)
        inv_line.pieces_uom = "PKG"
      end
      inv_line.unit_price = extract_decimal(line, (92..104), decimal_places: 3)
      inv_line.container_number = extract_string(line, (127..140))
      if inv_line.pieces&.nonzero? && inv_line.unit_price&.nonzero?
        inv_line.foreign_value = (inv_line.unit_price * inv_line.pieces).round(2)
      end
      # We're purposefully NOT populating the country of origin here.
      # The parts files that are fed into CMUS have this data already and apparently
      # it's more accurate than this feed.  So, we're just going to leave the country of origin
      # out.
      inv_line.country_of_export = shipment.country_of_export
      inv_line.container_number = extract_string(line, (127..140))
    end

    def add_entry_date shipment, line, pos, date_codes
      date = extract_date(line, pos, date_format: "%Y%m%d")
      return nil unless date
      Array.wrap(date_codes).each do |date_code|
        shipment.dates << CiLoadEntryDate.new(date_code, date)
      end
      date
    end

    def record_type line
      extract_string(line, (1..2))
    end

    # The following methods are protected to allow for potential extending classes to
    # override/extend them for potential customer specific handling (if needed)
    def new_shipment
      s = CiLoadEntry.new
      s.invoices = []
      s.containers = []
      s.dates = []
      s.bills_of_lading = []
      s
    end

    def new_commercial_invoice shipment
      i = CiLoadInvoice.new
      i.invoice_number = shipment.bills_of_lading.first.master_bill
      if i.invoice_number.blank?
        i.invoice_number = shipment.bills_of_lading.first.house_bill
      end
      i.charges = shipment.charges
      i.invoice_date = time_zone.now.to_date
      i.invoice_lines = []
      i
    end

    def new_commercial_invoice_line _shipment, _invoice
      CiLoadInvoiceLine.new
    end

    def time_zone
      ActiveSupport::TimeZone["America/New_York"]
    end

    def customer_number
      "TARGEN"
    end

    def find_target_part part_number
      Product.where(unique_identifier: part_number).first
    end

    def assortment_part? part
      return false unless part
      part.custom_value(cdefs[:prod_type]).to_s.downcase == "assortment"
    end

    def xvv_set_part? part
      return false unless part
      part.custom_value(cdefs[:prod_type]).to_s.downcase == "set"
    end

    def cdefs
      @cdefs ||= self.class.prep_custom_definitions [:prod_type, :tar_xvv]
    end

    def us
      @us ||= Country.where(iso_code: "US").first
      raise "No US country found." if @us.nil?
      @us
    end

end; end; end; end