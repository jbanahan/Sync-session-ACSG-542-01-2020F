require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vandegrift/cargowise_xml_support'

module OpenChain; module CustomHandler; module Vandegrift; class MaerskCargowiseBrokerInvoiceFileParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::Vandegrift::CargowiseXmlSupport

  def self.integration_folder
    ["#{MasterSetup.get.system_code}/maersk_cw_universal_transaction"]
  end

  def self.parse_file data, _log, opts = {}
    self.new.parse(xml_document(data), opts)
  end

  def parse doc, opts = {}
    doc = unwrap_document_root(doc)

    broker_reference = first_text doc, "UniversalTransaction/TransactionInfo/Job[Type='Job']/Key"
    if broker_reference.blank?
      inbound_file.add_reject_message "Broker Reference (Job Number) is required."
      return
    end
    inbound_file.add_identifier :broker_reference, broker_reference

    entry = nil
    Lock.acquire("Entry-Maersk-#{broker_reference}") do
      entry = Entry.where(broker_reference: broker_reference, source_system: Entry::CARGOWISE_SOURCE_SYSTEM).first_or_create! do |_ent|
        inbound_file.add_info_message "Cargowise-sourced entry matching Broker Reference '#{broker_reference}' was not found, so a new entry was created."
      end
    end
    Lock.with_lock_retry(entry) do
      inbound_file.set_identifier_module_info :broker_reference, Entry, entry.id

      # This element can't be nil because we've already verified broker_reference is not nil.  That comes from
      # within the TransactionInfo.
      elem_broker_inv = xpath(doc, "UniversalTransaction/TransactionInfo").first

      invoice_number = et elem_broker_inv, "JobInvoiceNumber"
      if invoice_number.blank?
        inbound_file.add_reject_message "Invoice Number is required."
        return
      end
      inbound_file.add_identifier :invoice_number, invoice_number

      broker_inv = entry.broker_invoices.find {|inv| inv.invoice_number == invoice_number }
      if broker_inv.nil?
        broker_inv = entry.broker_invoices.build(invoice_number: invoice_number, source_system: Entry::CARGOWISE_SOURCE_SYSTEM)
      end
      populate_broker_invoice broker_inv, elem_broker_inv

      broker_inv.broker_invoice_lines.destroy_all
      xpath(elem_broker_inv, "PostingJournalCollection/PostingJournal") do |elem_inv_line|
        inv_line = broker_inv.broker_invoice_lines.build
        populate_broker_invoice_line_from_element inv_line, elem_inv_line
      end

      # Add another line if there's a 'HST13' posting journal.  This line represents the sum of all HST on the invoice.
      elem_hst13_posting_journal = elem_broker_inv.xpath("PostingJournalCollection/PostingJournal[VATTaxID/TaxCode='HST13']").first
      if elem_hst13_posting_journal
        charge_amount = parse_decimal(et(elem_hst13_posting_journal, "LocalGSTVATAmount"))
        charge_description = first_text elem_hst13_posting_journal, "VATTaxID/Description"
        inv_line = broker_inv.broker_invoice_lines.build
        populate_broker_invoice_line inv_line, 'HST13', charge_amount, charge_description
      end

      if opts[:key] && opts[:bucket]
        broker_inv.last_file_path = opts[:key]
        broker_inv.last_file_bucket = opts[:bucket]
      end

      broker_inv.save!
      inbound_file.set_identifier_module_info InboundFileIdentifier::TYPE_INVOICE_NUMBER, BrokerInvoice, broker_inv.id

      entry.update!(broker_invoice_total: entry.broker_invoices.sum(:invoice_total),
                    total_duty_direct: self.class.deferred_duty?(broker_inv) ? entry.total_duty_taxes_fees_amount : nil,
                    last_billed_date: entry.broker_invoices.maximum(:invoice_date))

      inbound_file.add_info_message "Broker invoice successfully processed."
    end
  end

  def self.deferred_duty? broker_invoice
    broker_invoice.charge_code? "201"
  end

  private

    def populate_broker_invoice inv, elem
      inv.invoice_date = parse_date(et(elem, "CreateTime"))
      inv.invoice_total = parse_decimal(et(elem, "LocalTotal"))
      inv.currency = first_text elem, "PostingJournalCollection/PostingJournal/ChargeCurrency/Code"

      elem_bill_to = xpath(elem, "ShipmentCollection/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='SendersLocalClient']").first
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
      @time_zone ||= ActiveSupport::TimeZone["America/New_York"]
    end

    def parse_decimal dec_str
      dec_str.try(:to_d) || BigDecimal(0)
    end

    def get_bill_to_country_id elem_bill_to
      iso = first_text elem_bill_to, "Country/Code"
      iso.present? ? Country.where(iso_code: iso).first.try(:id) : nil
    end

    def populate_broker_invoice_line_from_element inv_line, elem
      charge_code = first_text(elem, "ChargeCode/Code")
      charge_amount = parse_decimal(et(elem, "LocalAmount"))
      charge_description = first_text(elem, "ChargeCode/Description")
      populate_broker_invoice_line inv_line, charge_code, charge_amount, charge_description
    end

    def populate_broker_invoice_line inv_line, charge_code, charge_amount, charge_description
      inv_line.charge_code = charge_code
      inv_line.charge_amount = charge_amount
      inv_line.charge_description = charge_description
    end

end; end; end; end