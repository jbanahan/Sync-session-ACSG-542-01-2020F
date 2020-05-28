require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'
require 'open_chain/entity_compare/comparator_helper'
require 'digest'

module OpenChain; module CustomHandler; module Amazon; class AmazonBillingFileGenerator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport
  include OpenChain::EntityCompare::ComparatorHelper

  class AmazonBillingError < StandardError; end

  # This is simply a sync record we're going to add to ANY broker invoice we've already generated billing data for
  # We'll then use the more specific sync codes to associate sync records with the actual files we're generating
  # for the Duty files, the brokerage charge files, and the bill of lading level charges.
  PRIMARY_SYNC ||= "AMZN BILLING"
  DUTY_SYNC ||= "AMZN BILLING DUTY"
  BROKERAGE_SYNC ||= "AMZN BILLING BROKERAGE"

  def generate_and_send entry_snapshot_json
    # Don't even bother trying to send anything if there are failing business rules...
    return unless mf(entry_snapshot_json, "ent_failed_business_rules").blank?

    # find all the broker invoices, then we can determine which one actually has been billed or not.
    broker_invoice_snapshots = extract_billable_invoices(entry_snapshot_json)

    return if broker_invoice_snapshots.length == 0

    return unless all_data_present?(entry_snapshot_json)

    entry = find_entity_object_by_snapshot_values(entry_snapshot_json, broker_reference: :ent_brok_ref, customer_number: :ent_cust_num)
    return if entry.nil?

    # Lock the entry entirely because of how we have to update the broker references associated with the entry
    # and the way the kewill entry parser has to copy the broker invoice data across from an old broker invoice record
    # to a new one.
    Lock.db_lock(entry) do
      unsent_invoices(entry, broker_invoice_snapshots).each do |invoice_data|
        generate_and_send_invoice_files(entry_snapshot_json, invoice_data[:snapshot], invoice_data[:invoice])
      end
    end

    nil
  end

  def generate_and_send_invoice_files(entry_snapshot, invoice_snapshot, invoice)
    if extract_duty_charges(invoice_snapshot).length > 0 && needs_sending?(invoice, :duty)
      begin
        generate_and_send_invoice_xml(entry_snapshot, invoice_snapshot, invoice, :duty)
      rescue => e
        handle_errored_sends(invoice, :duty, e)
        return nil
      end
    end

    if extract_brokerage_charges(invoice_snapshot).length > 0 && needs_sending?(invoice, :brokerage)
      begin
        generate_and_send_invoice_xml(entry_snapshot, invoice_snapshot, invoice, :brokerage)
      rescue => e
        handle_errored_sends(invoice, :brokerage, e)
        return nil
      end
    end

    sync_record = find_or_build_sync_record(invoice, PRIMARY_SYNC)
    sync_record.sent_at = Time.zone.now
    sync_record.confirmed_at = Time.zone.now + 1.minute
    sync_record.failure_message = nil

    sync_record.save!

    nil
  end

  def generate_and_send_invoice_xml(entry_snapshot, invoice_snapshot, invoice, invoice_type)
    root = generate_transmission_xml do |xml|
      generate_invoice_xml entry_snapshot, invoice_snapshot, xml, invoice_type
    end
    send_invoice_xml(invoice, invoice_type, root)
  end

  def ftp_credentials
    connect_vfitrack_net("to_ecs/amazon_invoice")
  end

  private

    def extract_billable_invoices entry_snapshot_json
      # The only invoices we should be billing are those where 'AMZN' is the bill to customer.
      # For most accounts, operations should be billing everything to Amazon (AMZN) but for about
      # 25% of the amazon accounts we're going to be billing duty directly to the account and NOT to
      # Amazon. Operations should then be billing any brokerage to AMZN and then in a separate
      # invoice billing the duty to the individual account (.ie NOT Amazon).
      # The billing for the individual accounts is done manually as this feed is SOLELY for
      # billing directly to Amazon.  Account Receivable will handle the individual billing,
      # ergo, we're only going to extract invoices where AMZN is the bill to.
      invoices = []
      json_child_entities(entry_snapshot_json, "BrokerInvoice") do |invoice|
        invoices << invoice if mf(invoice, :bi_customer_number) == "AMZN"
      end

      invoices
    end

    def all_data_present? entry_snapshot
      # invoice type doesn't matter here...
      meta_data = billing_meta_data(entry_snapshot, :duty)
      required_fields = [:ent_entry_port_code, :ent_release_date, :ent_mfids, :ent_ult_con_name, :ent_carrier_code, :ent_transport_mode_code]
      if meta_data.ocean?
        required_fields.push *[:ent_mbols, :ent_fcl_lcl, :ent_lading_port_code]
        required_fields << amazon_bill_of_lading(entry_snapshot)
      else
        required_fields << :ent_hbols
      end

      # Entry Filed date is set by the system to be based on a customs response date, but since we can't sumbit test files to customs, then
      # the filed date will remain blank.
      # Ergo, for test files, filed date is always going to be blank, so don't validate it when testing.
      if MasterSetup.get.production?
        required_fields << :ent_filed_date
      end

      # All the required_fields need to have data
      required_fields.map { |f| (f.is_a?(Symbol) ? mf(entry_snapshot, f) : f).present? }.uniq.all?
    end

    def unsent_invoices entry, broker_invoice_snapshots
      invoices = []
      broker_invoice_snapshots.each do |bi|
        invoice_number = mf(bi, "bi_invoice_number")
        broker_invoice = entry.broker_invoices.find {|inv| inv.invoice_number == invoice_number}

        # It's possible the invoice won't be found because it may have been updated in the intervening time from Kewill
        next if broker_invoice.nil? || broker_invoice.sync_records.find {|s| s.trading_partner == PRIMARY_SYNC && s.sent_at.present? }.present?

        invoices << {snapshot: bi, invoice: broker_invoice}
      end

      invoices
    end

    def needs_sending? invoice, invoice_type
      trading_partner = invoice_type_trading_partner(invoice_type)
      sr = invoice.sync_records.find {|sr| sr.trading_partner == trading_partner }
      sr.nil? || sr.sent_at.nil?
    end

    def handle_errored_sends invoice, invoice_type, error
      sync_record = find_or_build_sync_record invoice, invoice_type_trading_partner(invoice_type)
      sync_record.failure_message = error.message
      sync_record.save!
      # Don't bother using the log_me function here...it's just spamming our email list with issues because operations
      # continues to bill invalid codes.  The issues themselves ARE logged to the sync records so it should be fine.
      error.log_me unless error.is_a?(AmazonBillingError)
      nil
    end

    def send_invoice_xml broker_invoice, invoice_type, xml
      now = Time.zone.now
      # Since the invoice number AND the current time are part of the prefix, the likelihood we actually hit a collision
      # is extremely low, so we don't have to add too many digits to the sha hash below to make it unique
      prefix = "Invoice_DMCQ_#{broker_invoice.invoice_number}_#{now.strftime("%Y%m%d%H%M%S")}"

      filename = "#{prefix}_#{Digest::SHA256.hexdigest("#{prefix}#{now.to_f.to_s}")[0, 8]}.xml"

      Tempfile.open([File.basename(prefix), ".xml"]) do |temp|
        Attachment.add_original_filename_method(temp, filename)
        write_xml(xml, temp)
        temp.rewind

        sync_record = find_or_build_sync_record broker_invoice, invoice_type_trading_partner(invoice_type)

        ftp_sync_file temp, sync_record

        sync_record.sent_at = Time.zone.now
        sync_record.confirmed_at = Time.zone.now + 1.minute
        # If we're updating an existing sync record, there might be a failure message, so clear it now that we have sent the data.
        sync_record.failure_message = nil

        sync_record.save!
      end
    end

    def find_or_build_sync_record broker_invoice, trading_partner
      sr = broker_invoice.sync_records.find {|sr| sr.trading_partner == trading_partner }
      if sr.nil?
        sr = broker_invoice.sync_records.build trading_partner: trading_partner
      end

      sr
    end

    def generate_transmission_xml
      # We're going to send 1 transmission document for every single invoice and not bother
      # to combine them together even if there's multiple invoices on the entry that could potentially
      # be sent at the same time (which generally won't happen anyway).
      xml, root = build_xml_document("Transmission")
      add_xml_identifier_data root, :transmission
      add_element(root, "messageCount", "1")
      add_element(root, "isTest", (MasterSetup.get.production? ? "0" : "1"))
      message = add_element(root, "Message")
      message.add_attribute("seq", "1")
      yield message

      xml
    end

    def add_xml_identifier_data xml, element_type
      add_element(xml, "sendingPartyID", "DMCQ")
      add_element(xml, "receivingPartyID", "AMAZON")
      add_element(xml, "#{element_type}ControlNumber", transmission_control_number)
      add_element(xml, "#{element_type}CreationDate", Time.zone.now.in_time_zone("America/New_York").strftime("%Y%m%d%H%M%S"))
      nil
    end

    def generate_invoice_xml entry_snapshot, invoice_snapshot, xml, invoice_type
      meta_data = billing_meta_data(entry_snapshot, invoice_type)

      add_xml_identifier_data xml, :message
      add_element(xml, "processType", "INVOICE")
      add_element(xml, "messageType", "US_CIV")
      add_element(xml, "InvoiceNumber", invoice_number(invoice_snapshot, meta_data))
      add_element(xml, "InvoiceDate", format_date(mf(invoice_snapshot, :bi_invoice_date)))
      add_element(xml, "ShippedDate", format_date(mf(entry_snapshot, :ent_release_date)))
      add_element(xml, "ShipmentMethodOfPayment", "CONTRACT")
      add_element(xml, "CurrencyCode", (mf(invoice_snapshot, :bi_currency) || "USD"))
      carrier_number = carrier_number(meta_data)
      add_element(xml, "accountNumber", carrier_number)
      add_element(xml, "CarrierNumber", carrier_number)
      carrier = carrier_address
      add_element(xml, "CarrierName", carrier.name)
      add_element(xml, "CarrierAddress1", carrier.line_1)
      add_element(xml, "CarrierAddress2", carrier.line_2)
      add_element(xml, "CarrierCity", carrier.city)
      add_element(xml, "CarrierStateOrProvinceCode", carrier.state)
      add_element(xml, "CarrierPostalCode", carrier.postal_code)
      add_element(xml, "CarrierCountryCode", carrier.country&.iso_code)
      add_element(xml, "BillToName", mf(invoice_snapshot, :bi_to_name))
      add_element(xml, "BillToAddress1", mf(invoice_snapshot, :bi_to_add1))
      add_element(xml, "BillToAddress2", mf(invoice_snapshot, :bi_to_add2))
      add_element(xml, "BillToCity", mf(invoice_snapshot, :bi_to_city))
      add_element(xml, "BillToStateOrProvinceCode", mf(invoice_snapshot, :bi_to_state))
      add_element(xml, "BillToPostalCode", mf(invoice_snapshot, :bi_to_zip))
      add_element(xml, "BillToCountryCode", mf(invoice_snapshot, :bi_to_country_iso))
      add_element(xml, "TermsNetDueDate", format_date(terms_due_date(invoice_snapshot)))

      ll = add_element(xml, "LoadLevel")

      mid = find_mid(entry_snapshot)
      raise AmazonBillingError, "Invoice #{mf(invoice_snapshot, :bi_invoice_number)} does not have any valid MID addresses." if mid.nil?

      add_element(ll, "ShipFromAddressEntityCode", "SH")
      add_element(ll, "ShipFromName", mid.name)
      add_element(ll, "ShipFromAddress1", mid.address_1)
      add_element(ll, "ShipFromAddress2", mid.address_2)
      add_element(ll, "ShipFromCity", mid.city)
      add_element(ll, "ShipFromStateOrProvinceCode", "")
      add_element(ll, "ShipFromPostalCode", mid.postal_code)
      add_element(ll, "ShipFromCountryCode", mid.country)

      add_element(ll, "ConsigneeAddressEntityCode", "CN")
      add_element(ll, "ConsigneeName", mf(entry_snapshot, :ent_ult_con_name))
      add_element(ll, "ConsigneeAdditionalName", "")
      add_element(ll, "ConsigneeAddress1", mf(entry_snapshot, :ent_consignee_address_1))
      add_element(ll, "ConsigneeAddress2", mf(entry_snapshot, :ent_consignee_address_2))
      add_element(ll, "ConsigneeCity", mf(entry_snapshot, :ent_consignee_city))
      add_element(ll, "ConsigneeStateOrProvinceCode", mf(entry_snapshot, :ent_consignee_state))
      add_element(ll, "ConsigneePostalCode", mf(entry_snapshot, :ent_consignee_postal_code))
      add_element(ll, "ConsigneeCountryCode", mf(entry_snapshot, :ent_consignee_country_code))
      add_element(ll, "StandardCarrierCode", "DMCQ")

      references = generate_references(entry_snapshot, meta_data)
      references.each_pair do |number_type, number|
        ref = add_element(ll, "Reference")
        add_element(ref, "ReferenceNumberType", number_type)
        add_element(ref, "ReferenceNumber", number)
      end

      invoice_lines = (duty_invoice_type?(invoice_type) ? extract_duty_charges(invoice_snapshot) : extract_brokerage_charges(invoice_snapshot))
      map = billing_code_map
      total_billed = BigDecimal("0")
      invoice_lines.each do |line|
        cost = add_element(ll, "Cost")
        code = mf(line, :bi_line_charge_code)
        mapped_code = map[code]
        if mapped_code.present?
          charge_amount = mf(line, :bi_line_charge_amount)
          add_element(cost, "ExtraCost", charge_amount)
          add_element(cost, "ExtraCostDefinition", mapped_code)
          total_billed += charge_amount
        else
          # In the absence of a catchall charge code...we're going to have to raise an error if an unexpected charge code
          # is utilized.

          # This is really a backup, there should be a business rule preventing the invoice from being billed if the charge
          # codes used are invalid.
          raise AmazonBillingError, "Invoice #{mf(invoice_snapshot, :bi_invoice_number)} has an invalid Charge Code of '#{code}'. Only pre-validated charge codes can be billed to Amazon. This invoice must be reversed and re-issued without the invalid code."
        end
      end
      summary = add_element(xml, "Summary")
      add_element(summary, "NetAmount", total_billed) # If there was VAT involved, this would be total_billed - VAT
      add_element(summary, "TotalMonetarySummary", total_billed)

      nil
    end

    def billing_code_map
      {
        "0008" => "INV", # Additional Customs Invoices
        "0009" => "LIN", # Additional Customs Lines
        "0070" => "BOA", # Annual Continuous Bond
        "0072" => "BON", # Bond Set-up Fee
        "0151" => "CAS", # Case Management Fee
        "0014" => "COU", # Courier Fee
        "0162" => "DIS", # Disbursement fees (only in case of customs clearance)
        "0050" => "EXM", # Exam Charges
        "0102" => "EXH", # Exam Handling
        "0249" => "HTS", # HTS Classification
        "0051" => "OSF", # On-Site Fee
        "0026" => "PGC", # FDA
        "0119" => "PGC", # NOAA
        "0146" => "PGC", # USDA
        "0198" => "PGC", # Lacey
        "0217" => "PGC", # FSVP
        "0237" => "PGC", # FSIS
        "0248" => "PGC", # OMC
        "0007" => "CUS", # Customs brokerage fees
        "0191" => "ISF", # Importer Security Filing
        "0001" => "DUT" # Duty fees
      }
    end

    def find_mid entry_snapshot
      @mid ||= begin
        mids = Entry.split_newline_values(mf(entry_snapshot, :ent_mfids))
        address = nil
        mids.each do |mid|
          manufacturer = ManufacturerId.where(mid: mid).first
          if manufacturer.present?
            address = manufacturer
            break
          end
        end
        address
      end
    end

    def terms_due_date invoice_snapshot
      mf(invoice_snapshot, :bi_invoice_date) + 15.days
    end

    def carrier_number meta_data
      number = nil
      if meta_data.ocean?
        if meta_data.duty_type?
          number = "USMAEUGIFTDUTOCE"
        else
          number = meta_data.lcl? ? "USMAEUGIFTCUBROCECFS" : "USMAEUGIFTCUBROCECYFCL"
        end
      else
        number = (meta_data.duty_type? ? "USMAEUGIFTDUTAIR" : "USMAEUGIFTCUBRAIR")
      end

      number
    end

    def carrier_address
      a = Address.where(system_code: "Accounts Receivable").joins(:company).where(companies: {master: true}).first

      if a.nil?
        c = Company.where(master: true).first
        Lock.db_lock(c) do
          a = c.addresses.where(system_code: "Accounts Receivable").first
          if a.nil?
            a = Address.new(system_code: "Accounts Receivable", name: "Vandegrift, Inc.", line_1: "100 Walnut Ave", line_2: "Suite 600", city: "Clark", state: "NJ", postal_code: "07066", country_id: Country.where(iso_code: "US").first&.id)
            c.addresses << a
          end
        end
      end

      a
    end

    class BillingMetaData
      attr_reader :mode, :service_type, :invoice_type

      def initialize mode_of_transportation, service_type, invoice_type
        @mode = mode_of_transportation
        @service_type = service_type
        @invoice_type = invoice_type
      end

      def duty_type?
        @invoice_type == :duty
      end

      def brokerage_type?
        @invoice_type == :brokerage
      end

      def ocean?
        Entry.get_transport_mode_codes_us_ca("SEA").include?(@mode.to_i)
      end

      def air?
        Entry.get_transport_mode_codes_us_ca("AIR").include?(@mode.to_i)
      end

      def lcl?
        @service_type.to_s.upcase.include?("LCL")
      end

      def fcl?
        @service_type.to_s.upcase.include?("FCL")
      end
    end

    def billing_meta_data entry_snapshot, invoice_type
      BillingMetaData.new(mf(entry_snapshot, :ent_transport_mode_code).to_i, mf(entry_snapshot, :ent_fcl_lcl), invoice_type)
    end

    def generate_references entry_snapshot, meta_data
      references = {}
      references["TENDERID"] = tender_id(entry_snapshot, meta_data)
      if meta_data.ocean?
        references["MBL"] = amazon_bill_of_lading(entry_snapshot)
        references["HBL"] = mf(entry_snapshot, :ent_hbols, split_values: true).first
        references["SHIPMODE"] = "OCEAN"
        references["CONSIGNMENT"] = mf(entry_snapshot, :ent_total_packages)
      elsif meta_data.air?
        references["AWB"] = mf(entry_snapshot, :ent_hbols, split_values: true).first
        references["SHIPMODE"] = "AIR"
      end

      references["ORIGINPORT"] = mf(entry_snapshot, :ent_lading_port_name)
      references["DESTINATIONPORT"] = mf(entry_snapshot, :ent_entry_port_name)
      references["ENTRYSTARTDATE"] = format_date(mf(entry_snapshot, :ent_filed_date))
      references["ENTRYENDDATE"] = format_date(mf(entry_snapshot, :ent_release_date))

      if meta_data.duty_type?
        references["SERVICETYPE"] = "DUTY"
        references["ENTRYID"] = mf(entry_snapshot, :ent_entry_num)
      else
        references["SERVICETYPE"] = "Import Customs Clearance"

        if meta_data.ocean? && meta_data.fcl?
          references["CONTAINERID"] = mf(entry_snapshot, :ent_entry_num)
        else
          references["ENTRYID"] = mf(entry_snapshot, :ent_entry_num)
        end
      end

      references
    end

    def tender_id entry_snapshot, meta_data
      tender = "#{meta_data.duty_type? ? "DCD" : "DCB"}_DMCQ"

      if meta_data.air?
        tender += mf(entry_snapshot, :ent_hbols, split_values: true).first
      else
        tender += amazon_bill_of_lading(entry_snapshot)
      end

      tender
    end

    def amazon_bill_of_lading entry_snapshot
      mf(entry_snapshot, :ent_customer_references, split_values: true).find { |ref| ref.to_s.starts_with? "AMZD" }.to_s
    end

    # My understanding of this control number thing is that it's supposed to be a unique sequential
    # value for all documents sent by the carrier (us).  In other words, it's the equivalent of
    # and EDI ISA13 control number.  We're just going to try and use the current timestamp
    # at the finest granularity possible and then introduce a locking block to prevent any
    # other process from possibly using the same value.
    def transmission_control_number
      number = nil
      Lock.acquire("AmazonTransmissionControl", yield_in_transaction: false) do

        sleep(0.01)
        number = Time.zone.now.to_f.to_s.gsub(".", "")
      end
      number
    end

    def extract_duty_charges invoice_snapshot
      extract_charges(invoice_snapshot) do |line|
        code = mf(line, :bi_line_charge_code)
        !skip_brokerage_codes.include?(code) && duty_charge_codes.include?(code)
      end
    end

    def duty_charge_codes
      Set.new ["0001"]
    end

    def skip_brokerage_codes
      # 99 is duty direct
      # 0600 is freight direct
      # 0090 is Drawback (which has no commercial invoice data)
      Set.new ["0099", "0600", "0090"]
    end

    def extract_brokerage_charges invoice_snapshot
      extract_charges(invoice_snapshot) do |line|
        code = mf(line, :bi_line_charge_code)
        !skip_brokerage_codes.include?(code) && !duty_charge_codes.include?(code)
      end
    end

    def extract_charges invoice_snapshot, &block
      charges = []
      json_child_entities(invoice_snapshot, "BrokerInvoiceLine").each do |line|
        charges << line if block.call(line)
      end

      charges
    end

    def invoice_type_trading_partner invoice_type
      duty_invoice_type?(invoice_type) ? DUTY_SYNC : BROKERAGE_SYNC
    end

    def duty_invoice_type? invoice_type
      invoice_type == :duty
    end

    def format_date value, format: "%Y%m%d", timezone: default_timezone
      return "" if value.nil?
      value = value.in_time_zone(default_timezone) if value.respond_to?(:acts_like_time?) && value.acts_like_time?
      value.strftime(format)
    end

    def default_timezone
      @tz ||= ActiveSupport::TimeZone["America/New_York"]
    end

    def invoice_number invoice_snapshot, meta_data
      "#{mf(invoice_snapshot, :bi_invoice_number)}_#{meta_data.duty_type? ? "D" : "B"}"
    end

end; end; end; end