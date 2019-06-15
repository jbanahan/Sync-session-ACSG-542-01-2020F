require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module Crocs; class Crocs210Generator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport

  def accepts? event, entry
    # We could check that we have unsent invoice to process here, but I think it's probably just
    # easier to check the simple things and then just no-op in the event processing step if 
    # there are no invoices left to actually send
    ['CROCS', 'CROCSSAM'].include?(entry.customer_number) && entry.broker_invoices.length > 0 && !entry.last_billed_date.nil? &&
      MasterSetup.get.system_code == 'www-vfitrack-net'
  end

  def receive event, entry
    sync_record = entry.sync_records.where(trading_partner: "crocs 210").first_or_create(fingerprint: "")
    sent_invoices = sync_record.fingerprint.split "\n"
    
    invoices_to_send = entry.broker_invoices.collect {|inv| sent_invoices.include?(inv.invoice_number) ? nil : inv}.compact

    unless invoices_to_send.blank?
      invoices_to_send.each do |invoice|

        # For some operational purpsose, if there are inland / cartage services on the invoice they cannot be sent
        # via the 210 feed and must instead be manaully billed by operations.
        if has_cartage_services? invoice
          OpenMailer.send_crocs_manual_bill_reminder(invoice.invoice_number).deliver_now
        else
          xml = generate_xml invoice

          # XML might be blank if the invoices have no charges that should be
          # transmitted to Crocs
          unless xml.blank?
            Tempfile.open(["Crocs210-#{invoice.invoice_number.strip}-",'.xml']) do |t|
              t << xml.to_s
              t.flush
              ftp_file t
            end
          end
        end
      end
      sync_record.update_attributes! fingerprint: (sent_invoices+invoices_to_send.map(&:invoice_number)).join("\n"), sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute)
    end
    nil
  end

  def ftp_credentials
    ftp2_vandegrift_inc "to_ecs/Crocs/210"
  end

  def generate_xml broker_invoice
    doc, root = build_xml_document "Crocs210"

    entry = broker_invoice.entry

    entry.split_master_bills_of_lading.each do |mb|
      add_element root, "MasterBill", mb
    end

    entry.split_house_bills_of_lading.each do |hb|
      add_element root, "HouseBill", hb
    end

    add_element root, "FileNumber", entry.broker_reference
    add_element root, "EntryNumber", entry.entry_number
    add_element root, "PortOfLading", entry.lading_port_code
    add_element root, "PortOfUnlading", entry.unlading_port_code
    add_element root, "DescriptionOfGoods", entry.merchandise_description
    add_element root, "PieceCount", entry.total_packages
    add_element root, "GrossWeight", entry.gross_weight
    add_element root, "ArrivalDate", (entry.arrival_date ? entry.arrival_date.in_time_zone("Eastern Time (US & Canada)").to_date : nil)
    add_element root, "ConsigneeName", entry.ult_consignee_name
    importer = entry.importer
    add_element root, "ImporterName", importer.name

    address = importer.addresses.where(name: "210").first
    if address
      add_element root, "ImporterAddress", address.line_1
      add_element root, "ImporterCity", address.city
      add_element root, "ImporterState", address.state
      add_element root, "ImporterZip", address.postal_code
    end

    total_lines = 0

    lines = broker_invoice.broker_invoice_lines.collect {|line| include_charge?(line) ? line : nil}.compact

    # Don't include invoices where there's no lines we're actually sending to Crocs
    if lines.length > 0
      total_lines += lines.length

      inv = add_element root, "Invoice"

      add_element inv, "Number", broker_invoice.invoice_number.strip
      add_element inv, "Total", sprintf("%.2f", broker_invoice.invoice_total)
      add_element inv, "Currency", broker_invoice.currency

      lines.each do |line|

        charge = add_element inv, "Charge"
        add_element charge, "Type", line.charge_type
        add_element charge, "Amount", sprintf("%.2f", line.charge_amount)
        add_element charge, "Code", line.charge_code
        add_element charge, "Description", line.charge_description
      end
    end

    # It's possible that we'll end up not actually having any invoice lines that 
    # we added to the xml, in which case, don't bother sending anything.
    total_lines > 0 ? doc : nil
  end

  private
    def include_charge? charge
      ['R', 'O', 'C'].include? charge.charge_type
    end

    def has_cartage_services? invoice
      invoice.broker_invoice_lines.select {|line| line.charge_type.try(:upcase) == "T"}.length > 0
    end

end; end; end; end