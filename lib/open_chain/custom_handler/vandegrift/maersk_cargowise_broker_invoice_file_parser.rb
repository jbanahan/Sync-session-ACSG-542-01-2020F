require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/nokogiri_xml_helper'

module OpenChain; module CustomHandler; module Vandegrift; class MaerskCargowiseBrokerInvoiceFileParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::NokogiriXmlHelper

  def self.integration_folder
    ["#{MasterSetup.get.system_code}/maersk_cw_universal_transaction"]
  end

  def self.parse_file data, log, opts={}
    doc = Nokogiri::XML(data)
    # Eliminate namespaces from the document.  If this is not done, the xpath xpressions need to be namespaced.
    # # Since there's only a single namespace in these CW documents, there's no harm in tossing it.
    doc.remove_namespaces!
    self.new.parse(doc, opts)
  end

  def parse doc, opts={}
    # Root varies depending on how the XML is exported.  Dump UniversalInterchange/Body from the structure if it's included.
    if doc.root.name == 'UniversalInterchange'
      doc = doc.xpath "UniversalInterchange/Body"
    end

    broker_reference = first_text doc, "UniversalTransaction/TransactionInfo/Job[Type='Job']/Key"
    if broker_reference.blank?
      inbound_file.add_reject_message "Broker Reference (Job Number) is required."
      return
    end
    inbound_file.add_identifier :broker_reference, broker_reference

    entry = nil
    Lock.acquire("Entry-Maersk-#{broker_reference}") do
      entry = Entry.where(broker_reference:broker_reference, source_system:Entry::CARGOWISE_SOURCE_SYSTEM).first_or_create! do |ent|
        inbound_file.add_info_message "Cargowise-sourced entry matching Broker Reference '#{broker_reference}' was not found, so a new entry was created."
      end
    end
    Lock.with_lock_retry(entry) do
      inbound_file.set_identifier_module_info :broker_reference, Entry, entry.id

      # This element can't be nil because we've already verified broker_reference is not nil.  That comes from
      # within the TransactionInfo.
      elem_broker_inv = doc.xpath("UniversalTransaction/TransactionInfo").first

      invoice_number = et elem_broker_inv, "JobInvoiceNumber"
      if invoice_number.blank?
        inbound_file.add_reject_message "Invoice Number is required."
        return
      end
      inbound_file.add_identifier :invoice_number, invoice_number

      broker_inv = entry.broker_invoices.find {|inv| inv.invoice_number == invoice_number }
      if broker_inv.nil?
        broker_inv = entry.broker_invoices.build(invoice_number:invoice_number, source_system:Entry::CARGOWISE_SOURCE_SYSTEM)
      end
      populate_broker_invoice broker_inv, elem_broker_inv

      broker_inv.broker_invoice_lines.destroy_all
      elem_broker_inv.xpath("PostingJournalCollection/PostingJournal").each do |elem_inv_line|
        inv_line = broker_inv.broker_invoice_lines.build
        populate_broker_invoice_line inv_line, elem_inv_line
      end

      if opts[:key] && opts[:bucket]
        broker_inv.last_file_path = opts[:key]
        broker_inv.last_file_bucket = opts[:bucket]
      end

      broker_inv.save!
      inbound_file.set_identifier_module_info InboundFileIdentifier::TYPE_INVOICE_NUMBER, BrokerInvoice, broker_inv.id

      entry.update_attributes!(broker_invoice_total: entry.broker_invoices.sum(:invoice_total),
                               total_duty_direct: self.class.is_deferred_duty?(broker_inv) ? entry.total_duty_taxes_fees_amount : nil,
                               last_billed_date: entry.broker_invoices.maximum(:invoice_date))

      inbound_file.add_info_message "Broker invoice successfully processed."
    end
  end

  def self.is_deferred_duty? broker_invoice
    broker_invoice.has_charge_code? "201"
  end

  private

    def populate_broker_invoice inv, elem
      inv.invoice_date = parse_date(et elem, "CreateTime")
      inv.invoice_total = parse_decimal(et elem, "LocalTotal")

      elem_bill_to = elem.xpath("ShipmentCollection/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='SendersLocalClient']").first
      if elem_bill_to
        inv.customer_number = et elem_bill_to, "OrganizationCode"
        inv.bill_to_name = et elem_bill_to, "CompanyName"
        inv.bill_to_address_1 = et elem_bill_to, "Address1"
        inv.bill_to_address_2 = et elem_bill_to, "Address2"
        inv.bill_to_city = et elem_bill_to, "City"
        inv.bill_to_state = et elem_bill_to, "State"
        inv.bill_to_zip = et elem_bill_to, "Postcode"
        inv.bill_to_country_id = get_bill_to_country_id elem_bill_to
      end
    end

    def parse_date date_str
      date_str.present? ? time_zone.parse(date_str).to_date : nil
    end

    def time_zone
      # All times provided in the document are assumed to be from this zone.
      @zone ||= ActiveSupport::TimeZone["America/New_York"]
    end

    def parse_decimal dec_str
      dec_str.try(:to_d) || BigDecimal.new(0)
    end

    def get_bill_to_country_id elem_bill_to
      iso = first_text elem_bill_to, "Country/Code"
      iso.present? ? Country.where(iso_code:iso).first.try(:id) : nil
    end

    def populate_broker_invoice_line inv_line, elem
      inv_line.charge_code = first_text elem, "ChargeCode/Code"
      inv_line.charge_amount = parse_decimal(et elem, "LocalAmount")
      inv_line.charge_description = first_text elem, "ChargeCode/Description"
    end

end; end; end; end