require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; class Generic210Generator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport
  include ActionView::Helpers::NumberHelper

  SUPPRESS_ACCOUNTING_CODES = Set.new(["0097", "0098", "0099", "0105", "0106", "0107", "0600", "0601", "0602", "0603", "0604"])

  def accepts? event, entry
    # Just check if the customer has a setup, at this point..if so, then accept.  We'll decide in receive if we're actually generating anything or not
    MasterSetup.get.system_code == 'www-vfitrack-net' && billing_setup(entry)
  end

  def receive event, entry
    if billing_setup(entry)
      # The sync record fingerprint is going to just be a \n delimited list of the broker invoice numbers we've already sent.
      # Any new invoice numbers we encounter will get sent and then the fingerpint list is rebuilt and saved off to include the
      # new numbers.
      Lock.acquire("210-#{entry.broker_reference}") do 
        sync_record = entry.sync_records.where(trading_partner: "210").first_or_create(fingerprint: "")
        sent_invoices = sync_record.fingerprint.split "\n"
        
        invoices_to_send = entry.broker_invoices.collect {|inv| sent_invoices.include?(inv.invoice_number) ? nil : inv}.compact

        unless invoices_to_send.blank?
          sent_count = 0
          invoices_to_send.each do |invoice|
            xml = generate_xml invoice, default_timezone, (sent_invoices.size == 0 && sent_count == 0)

            # XML might be blank if the invoices have no charges that should be transmitted
            unless xml.blank?
              Tempfile.open(["VFI210-#{invoice.invoice_number.strip}-",'.xml']) do |t|
                t << xml.to_s
                t.flush
                t.rewind
                ftp_file t
                sent_count += 1
              end
            end
          end
          sync_record.update_attributes! fingerprint: (sent_invoices+invoices_to_send.map(&:invoice_number)).join("\n"), sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute)
        end
      end
    end

    nil
  end

  def generate_xml broker_invoice, timezone, primary_invoice
    doc, root = build_xml_document "Vfitrack210"

    entry = broker_invoice.entry

    add_element root, "BrokerReference", v(:ent_brok_ref, entry)
    add_element root, "EntryNumber", v(:ent_entry_num, entry)
    add_element root, "CustomerNumber", v(:ent_cust_num, entry)
    add_element root, "CarrierCode", v(:ent_carrier_code, entry)


    add_element root, "PortOfLading", v(:ent_lading_port_code, entry)
    add_element root, "PortOfUnlading", v(:ent_unlading_port_code, entry)
    add_element root, "DescriptionOfGoods", v(:ent_merch_desc, entry)
    add_element root, "PieceCount", v(:ent_total_packages, entry)
    add_element root, "GrossWeight", v(:ent_gross_weight, entry)

    add_date_elements root, (entry.arrival_date ? entry.arrival_date.in_time_zone(timezone).to_date : nil), child_element_name: "ArrivalDate"
    add_date_elements root, (entry.export_date ? entry.export_date : nil), child_element_name: "ExportDate"

    add_entity_address_info root, "Consignee", name: v(:ent_ult_con_name, entry), id: v(:ent_ult_con_code, entry), address_1: v(:ent_consignee_address_1, entry), 
                              address_2: v(:ent_consignee_address_2, entry), city: v(:ent_consignee_city, entry), state: v(:ent_consignee_state, entry)
    
    add_entity_address_info root, "BillTo", name: v(:bi_to_name, broker_invoice), id: v(:bi_customer_number, broker_invoice), address_1: v(:bi_to_add1, broker_invoice), 
                              address_2: v(:bi_to_add2, broker_invoice), city: v(:bi_to_city, broker_invoice), state: v(:bi_to_state, broker_invoice), zip: v(:bi_to_zip, broker_invoice), country: v(:bi_to_country_iso, broker_invoice)

    add_collection_element root, "MasterBills", "MasterBill", v(:ent_mbols, entry)
    add_collection_element root, "HouseBills", "HouseBill", v(:ent_hbols, entry)
    add_collection_element root, "Containers", "Container", v(:ent_container_nums, entry)
    add_collection_element root, "PoNumbers", "PoNumber", v(:ent_po_numbers, entry)

    total_lines = 0

    lines = charge_lines(broker_invoice)

    # Don't include invoices where there's no lines we're actually sending out (if they were all suppressed)
    if lines.length > 0
      total_lines += lines.length

      inv = add_element root, "Invoice"

      add_element inv, "InitialInvoice", (primary_invoice === true ? "Y" : "N")
      add_element inv, "Number", v(:bi_invoice_number, broker_invoice)
      add_element inv, "Total", number_with_precision(v(:bi_invoice_total, broker_invoice), precision: 2)
      add_element inv, "Currency", v(:bi_currency, broker_invoice)
      add_date_elements inv, v(:bi_invoice_date, broker_invoice), child_element_name: "InvoiceDate"

      line_num = 0
      lines.each do |line|
        charge = add_element inv, "Charge"
        add_element charge, "LineNumber", (line_num += 1)
        add_element charge, "Type", v(:bi_line_charge_type, line)
        add_element charge, "Amount", number_with_precision(v(:bi_line_charge_amount, line), precision: 2)
        add_element charge, "Code", v(:bi_line_charge_code, line)
        add_element charge, "Description", v(:bi_line_charge_description, line)
      end
    end

    # It's possible that we'll end up not actually having any invoice lines that 
    # we added to the xml, in which case, don't bother sending anything.
    total_lines > 0 ? doc : nil
  end

  protected
    def ftp_credentials
      connect_vfitrack_net 'to_ecs/210'
    end

    def default_timezone
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end

    def charge_lines invoice
      # We need to weed out the invoice lines that are not actual charges.  These are Duty lines (charge code = 1) on an invoice where there 
      # are also Duty Pd Direct lines (charge code = 99).  If there are no Duty Pd Direct lines, then we leave the Duty line in.

      # Other codes that should not be sent (.ie they're all marked as suppress_accounting in Alliance)
      # Advanced Payment - 0097
      # Freight Paid Direct - 0098
      # Duty - 0105
      # Merchandise Processing Fee - 0106
      # Harbor Maint Fee - 0107
      # Freight Paid Direct - 0600
      # Trucking Paid Direct - 0601
      # Customs Entry - 0602 
      # Freight Charges - 0603
      # Trucking Charges - 0604
      all_codes = Set.new(invoice.broker_invoice_lines.map {|line| line.charge_code})
      invoice.broker_invoice_lines.select do |line| 
        if line.charge_code == "0001"
          !all_codes.include?("0099")
        else
          !SUPPRESS_ACCOUNTING_CODES.include?(line.charge_code) 
        end
      end
    end


  private
    def v uid, entry
      ModelField.find_by_uid(uid).process_export entry, user, true
    end

    def user
      @user ||= User.integration
    end

    def billing_setup entry
      return nil if entry.customer_number.blank?

      @billing_setup ||= AutomatedBillingSetup.where(customer_number: entry.customer_number).first

      (@billing_setup && @billing_setup.sendable?(entry)) ? @billing_setup : nil
    end

end; end; end