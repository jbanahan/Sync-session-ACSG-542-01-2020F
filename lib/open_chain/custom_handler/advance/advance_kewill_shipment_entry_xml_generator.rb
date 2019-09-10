require 'open_chain/custom_handler/vandegrift/kewill_shipment_entry_xml_generator'

module OpenChain; module CustomHandler; module Advance; class AdvanceKewillShipmentEntryXmlGenerator < OpenChain::CustomHandler::Vandegrift::KewillShipmentEntryXmlGenerator

  def generate_shipment_entry shipments
    entry = super

    # If the customer number is CQ, then change it to CQSOU
    entry.customer = "CQSOU" if entry.customer == "CQ"
    entry.consignee_code = entry.customer
    entry.ultimate_consignee_code = entry.customer

    # Put the house bill as the edi identifier...this is just the value kewill people will use
    # to look up the shipment data
    id = CiLoadEdiIdentifier.new
    scac, bill_number = chop_bill(shipments.first.house_bill_of_lading)
    id.master_bill = bill_number
    id.scac = scac

    entry.edi_identifier = id

    entry
  end

  def generate_kewill_shipment_data shipments
    entry = super

    # Pull the CiLoadEdiIdentifier's bill_number value down to all the invoice's file number field.
    # We're doing this because Advan / CQ can have the same commercial invoice # across different bill's of lading / shipments
    # This ends up causing a unique key constraint error in Kewill's database UNLESS we use a distinct value for each invoice
    # as the file number field (the table is keyed on file number (manufacturer_id in Kewill), invoice number and invoice date).
    # So, we'll use the master bill (really the house for Advan) as that unique value.
    mbol = entry.edi_identifier&.master_bill
    entry.invoices.each do |inv|
      inv.file_number = mbol
    end

    entry
  end

  def generate_kewill_shipment_container shipment, container
    c = super
    # This is to just keep the mapping from the original ADVAN feed of the container size
    # going to the container type field
    c.container_type = c.size
    c.size = nil
    c
  end

  def generate_kewill_shipment_invoice_line shipment_line
    inv_line = super(shipment_line)

    # For CQ, we need to determine if the part associated with the line has a set quantity associated
    # with it.  If so, then we need to multiply the commercial quantity by the set quantity 
    # to get the actual piece count.
    if !inv_line.nil?
      # Clear out the hts, by leaving it blank Kewill will look up the part data from the parts library and will
      # build out the full tariff line from that information.  If we put teh tariff number in there, it expects we'll
      # send quantity information and such.
      inv_line.hts = nil

      inv_line.pieces_uom = "NO"
      inv_line.unit_price_uom = "PCS"
    end
    
    inv_line
  end

  # The existing feed that we're replacing did not feed any bills of lading to Kewill, nobody really knows why
  # as the person that set it up is gone, but it's most likely because we don't have the true master bill for the 
  # shipment in the Prep 7501 that generates the shipment we're working with, only the house bill.  So, the 
  # value in the master bill in the shipment is really the house, and that's what's used as the EDI identifier
  # in as the master bill in the Kewill EDI system...and no Bills are sent.
  def generate_bills_of_lading shipments
    []
  end

  def cdefs
    @cdefs ||= (super).merge(self.class.prep_custom_definitions([:prod_units_per_set]))
  end

end; end; end; end