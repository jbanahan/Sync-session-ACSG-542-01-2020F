require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_sender_support'
require 'open_chain/custom_handler/fixed_position_parser_support'
require 'open_chain/custom_handler/target/target_support'

module OpenChain; module CustomHandler; module Target; class TargetEntryInitiationFileParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::FixedPositionParserSupport
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSenderSupport
  include OpenChain::CustomHandler::Target::TargetSupport

  def self.parse data, opts = {}
    self.new.parse(data, opts)
  end

  def parse data, opts = {}
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
        invoice_line = new_commercial_invoice_line(shipment, invoice)
        process_04(shipment, invoice, invoice_line, line)
        invoice.invoice_lines << invoice_line
      end
    end
    shipments.each {|s| finalize_shipment(s) }

    shipments
  end

  def process_01 shipment, line
    #TODO - Figure out if this is the correct customer number
    shipment.customer = "TARGET"
    bill_number = extract_string(line, (5..34))
    master_bill_number = extract_string(line, (35..64))
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
      if bill_number == master_bill_number
        bol.house_bill = bill_number
      else
        bol.house_bill = bill_number
        bol.master_bill = master_bill_number
      end
    else
      if bill_number == master_bill_number
        bol.master_bill = master_bill_number
      else
        bol.house_bill = bill_number
        bol.master_bill = master_bill_number
      end
    end
    
    shipment.vessel = extract_string(line, (67..101))
    shipment.voyage = extract_string(line, (102..106))
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

  def process_04 shipment, invoice, inv_line, line
    inv_line.po_number = extract_string(line, (35..46))

    # dpci is basically the unique item number for Target (DPCI = DePartment / Class / Item)
    # Vendor Order Point is essentially a code for the Factory.  Because some tariff data
    # differs between factories, we're having to concatenate the two together to make a fully
    # unique part number in CM.
    vendor_order_point = extract_string(line, (47..55))
    dpci = extract_string(line, (56..64))
    inv_line.part_number = build_part_number(dpci, vendor_order_point)
    inv_line.cartons = extract_integer(line, (65..73))
    inv_line.pieces = extract_integer(line, (83..91))
    inv_line.unit_price = extract_decimal(line, (92..104), decimal_places: 3)
    inv_line.container_number = extract_string(line, (127..140))
    if inv_line.pieces&.nonzero? && inv_line.unit_price&.nonzero?
      inv_line.foreign_value = (inv_line.unit_price * inv_line.pieces).round(2)
    end
    inv_line.country_of_origin = extract_string(line, (105..106))
    inv_line.country_of_export = shipment.country_of_export
    inv_line.container_number = extract_string(line, (127..140))
    nil
  end

  def finalize_shipment shipment
    # Clear the header leavel country of export (we copied it down to the line level)
    shipment.country_of_export = nil
  end

  def add_special_tariffs? entry, invoice, line
    # Don't add 301 tariffs to the feed...I'm presuming that Target will have 
    # them already in the parts data.
    false
  end

  private

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
      # Strip the charges out of the shipment (since we copied to the invoice)
      shipment.charges = nil

      i.invoice_date = time_zone.now.to_date
      i.invoice_lines = []
      i
    end

    def new_commercial_invoice_line shipment, invoice
      CiLoadInvoiceLine.new
    end

    def time_zone
      ActiveSupport::TimeZone["America/New_York"]
    end

end; end; end; end