require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module FootLocker; class FootLocker810Generator
  include OpenChain::XmlBuilder
  include ActionView::Helpers::NumberHelper

  def generate_xml broker_invoice
    doc, root = build_xml_document "FootLockerInvoice810"

    add_element root, "InvoiceNumber", broker_invoice.invoice_number.strip
    add_element root, "InvoiceDate", to_date(broker_invoice.invoice_date)

    entry = broker_invoice.entry

    entry.split_master_bills_of_lading.each do |mb|
      add_element root, "MasterBill", mb
    end

    entry.split_house_bills_of_lading.each do |hb|
      add_element root, "HouseBill", hb
    end

    add_element root, "FileNumber", entry.broker_reference
    add_element root, "EntryNumber", entry.entry_number
    add_element root, "CustomsEntryTypeCode", entry.entry_type
    add_element root, "RemitToName", "Vandegrift Forwarding Company, Inc."
    add_element root, "RemitToAdd1", "100 Walnut Ave."
    add_element root, "RemitToAdd2", "Suite 600"
    add_element root, "RemitToCity", "Clark"
    add_element root, "RemitToState", "NJ"
    add_element root, "RemitToPostal", "07066"
    add_element root, "ShippedDate", to_date(entry.export_date)
    add_element root, "CustomsClearance", to_date(entry.release_date)
    add_element root, "EntryFiledDate", to_date(entry.entry_filed_date)
    add_element root, "DOPrintDate", nil
    add_element root, "ArrivalDate", to_date(entry.arrival_date)
    add_element root, "ActualPortOfEntry", entry.entry_port_code
    add_element root, "VesselName", entry.vessel
    add_element root, "FlightVoyageNumber", entry.voyage
    add_element root, "SCAC", entry.carrier_code
    add_element root, "PortOfDischarge", entry.unlading_port_code
    add_element root, "PortOfEntry", entry.entry_port_code
    add_element root, "PortOfLoading", entry.lading_port_code
    add_element root, "TotalMonetaryAmount", get_total_monetary_amount(entry, broker_invoice)
    add_element root, "TotalCommercialInvoiceAmount", to_number(entry.total_invoiced_value)

    inv_lines = Set.new

    entry.commercial_invoice_lines.each do |line|
      # We want to make sure we're sending out the tariff number even if the PO is blank
      # In these cases, we'll send 0 as po.
      po = (line.po_number.presence || "0").strip
      inv = line.commercial_invoice.invoice_number.to_s.strip
      part = (line.part_number.presence || "0").strip

      line.commercial_invoice_tariffs.each do |t|
        next if t.hts_code.blank?

        inv_lines << [inv, po, part, t.hts_code].join("*~*")
      end
    end

    # We need to ensure that the Details/Detail/PoNumber tag is always present, regardless of whether we
    # have actual Detail elements below it for EDI handling purposes
    details = add_element root, "Details"
    if inv_lines.size == 0
      detail = add_element details, "Detail"
      add_element detail, "PoNumber", "0"
      add_element detail, "Tariff", "0"
      add_element detail, "Sku", "0"
      add_element detail, "InvoiceNumber", "0"
    else
      inv_lines.each do |line|
        detail = add_element details, "Detail"
        inv, po, part, hts = line.split("*~*")

        add_element detail, "PoNumber", po
        add_element detail, "Tariff", hts.hts_format
        add_element detail, "Sku", part
        add_element detail, "InvoiceNumber", inv
      end
    end

    lines = nil

    # Only include the Duty information on the initial invoice file (.ie the one sans suffix)
    if broker_invoice.suffix.blank?
      lines ||= add_element root, "Lines"
      if (entry.hmf && entry.hmf > 0)
        add_line (add_element lines, "Line"), "D", "HMF", "HMF FEE", entry.hmf
      end

      if (entry.mpf && entry.mpf > 0)
        add_line (add_element lines, "Line"), "D", "MPF", "MPF FEE", entry.mpf
      end

      if (entry.cotton_fee && entry.cotton_fee > 0)
        add_line (add_element lines, "Line"), "D", "CTN", "COTTON FEE", entry.cotton_fee
      end

      add_line (add_element lines, "Line"), "D", "0001", "DUTY", (entry.total_duty ? entry.total_duty : 0)
    end

    broker_invoice.broker_invoice_lines.each do |line|
      next if exclude_line?(entry, line)

      lines ||= add_element root, "Lines"
      inv_l = add_element lines, "Line"

      add_line inv_l, line.charge_type, line.charge_code, line.charge_description, line.charge_amount
    end

    # If we didn't add any charge lines, then don't bother sending the invoice xml
    lines.nil? ? nil : doc
  end

  private
    def to_date val
      out = nil
      if val
        if val.respond_to?(:in_time_zone)
          val = val.in_time_zone("Eastern Time (US & Canada)").to_date
        end

        out = val.iso8601
      end
      out
    end

    def to_number val
      val ? number_with_precision(val, precision:2) : nil
    end

    def add_line inv_l, type, code, desc, amount
      add_element inv_l, "Type", type
      add_element inv_l, "Code", code
      add_element inv_l, "Description", desc
      add_element inv_l, "Amount", to_number(amount)
    end

    def exclude_line? entry, line
      # Skip duty types.  We've accounted for them previously in the document.
      # EXCEPTION: FOOLO wants to see the Duty Paid Direct (0099) lines.
      (line.charge_type == "D" && line.charge_code != '0099') ||
      # Tax charges are not included in the Canadian 810.
      (is_canada?(entry) && is_canada_tax_charge_code?(line.charge_code))
    end

    def is_canada? entry
      FootLockerEntry810Comparator.is_foot_locker_canada? entry.customer_number
    end

    def is_canada_tax_charge_code? charge_code
      cc_num = charge_code.to_i
      cc_num == 2 || (cc_num >= 250 && cc_num < 260)
    end

    def get_total_monetary_amount entry, broker_invoice
      v = BigDecimal.new(0)
      if is_canada? entry
        # The Canadian broker invoice "invoice total" amount is the sum of all the charge amounts for its lines.
        # (See FenixInvoiceParser.)  Because we're leaving out GST-related lines from the 810, the total must be
        # recalculated.  It can't be used as is, like it can be for the US.
        broker_invoice.broker_invoice_lines.each do |line|
          next if exclude_line?(entry, line)
          v += line.charge_amount
        end
        v = to_number(v)
      else
        v = to_number(broker_invoice.invoice_total)
      end
      v
    end

end; end; end; end