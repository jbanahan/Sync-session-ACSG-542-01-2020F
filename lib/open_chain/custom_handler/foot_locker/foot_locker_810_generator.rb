require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module FootLocker; class FootLocker810Generator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport
  include ActionView::Helpers::NumberHelper

  def accepts? event, entry
    ['FOOLO', 'FOOCA', 'TEAED'].include?(entry.customer_number) && entry.broker_invoices.length > 0 && !entry.last_billed_date.nil? && MasterSetup.get.system_code == 'www-vfitrack-net'
  end

  def ftp_credentials
    connect_vfitrack_net 'to_ecs/foot_locker/810'
  end

  def receive event, entry
    sync_record = entry.sync_records.where(trading_partner: "foolo 810").first_or_create(fingerprint: "")
    sent_invoices = sync_record.fingerprint.split "\n"
    
    new_invoices = entry.broker_invoices.select {|inv| !sent_invoices.include? inv.invoice_number}

    # Due to the way we synthesize the duty fees (mpf, hmf, cotton fee, duty amounts), we're going to do a full resend 
    # of all the invoice data for the whole entry so FOOLO can just do a full replace of the data for all the invoice files.
    sent_invoices = []
    unless new_invoices.blank?
      entry.broker_invoices.each do |invoice|
        xml = generate_xml invoice

        # XML might be blank if the invoices have no charges that should be transmitted
        unless xml.blank?
          Tempfile.open(["Foolo810-#{invoice.invoice_number.strip}-",'.xml']) do |t|
            t << xml.to_s
            t.flush
            t.rewind
            ftp_file t
            sent_invoices << invoice.invoice_number
          end
        end
      end
      sync_record.update_attributes! fingerprint: sent_invoices.join("\n"), sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute)
    end
    nil
  end

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
    add_element root, "TotalMonetaryAmount", to_number(broker_invoice.invoice_total)
    add_element root, "TotalCommercialInvoiceAmount", to_number(entry.total_invoiced_value)

    po_numbers = {}
    entry.commercial_invoice_lines.each do |line|
      next if line.po_number.blank?
      po = line.po_number.strip

      line.commercial_invoice_tariffs.each do |t|
        next if t.hts_code.blank?

        po_numbers[po] ||= Set.new
        po_numbers[po] << t.hts_code
      end
    end

    # We need to ensure that the Details tag is always present, regardless of whether we
    # have actual Detail elements below it for EDI handling purposes
    details = add_element root, "Details"
    po_numbers.each_pair do |po, hts_codes|
      hts_codes.each do |hts|
        detail = add_element details, "Detail"

        add_element detail, "PoNumber", po
        add_element detail, "Tariff", hts.hts_format
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
      # Skip duty types, we've accounted for them above
      # EXCEPT, FOOLO wants to see the Duty Paid Direct (0099) lines
      next if line.charge_type == "D" && line.charge_code != '0099'

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


end; end; end; end